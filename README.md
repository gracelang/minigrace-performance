# Minigrace Performance

This repository records the results of some preliminary experiments that examine ways to speed-up method request in _minigrace_.

## The module "performance"

The *performance* module contains benchmarking code used to estimate speedup.  It is intended to measure the speed of the implementation, not to time specific functions.

```
method summarize (stats) {
    // stats is a collection of count@time pairs
    // checks that all the counts are the same, removes outliers repeatedly
    // until no more remain, and prints a summary of the data that is left.
    // It is necessary to remove outliers repeatedly because each removal reduces
    // the inter-quartile-range, thus branding more of the data as outliers.
}
    
method withoutOutliers (sorted) {
    // sorted is a sorted collection of numbers.  returns a sub-sequence of 
    // sorted that excludes outliers.  Outliers are defined as numbers 
    // that exceed the threshold (75%-percentile + 1.5 * inter-quartile-range)
}

method benchmark(aBlock) {
    // runs aBlock repeatedly until 10 seconds has passed.  
    // returns a list of points, in which the x component is the number of
    // requests executed, and the y component the time taken to execute them.
}

method now {
    // returns the current value of a high-precision millisecond timer
    native "js" code ‹return new GraceNum(performance.now());›
}

method time(aBlock) {
    // answers the time (in milliseconds) taken to execute aBlock.
    // Typically, the result exhibits high variability
}
```

The methods of the performance module are applied to a benchmark that exercises Grace's method request.  All object-oriented languages have method request — variously called message send or method invocation — as their basic operation.  Thus, if anything is to be fast, method request must be fast.  Our chosen benchmark is the Ackermann function, because it uses method request *a lot*.

## Module *ackermann_plain*

This is a simple implementation of the 2-argument Ackermann function, along with four tests of known values.  We report the results of

```
performance.summarize(performance.benchmark{ ackermann(3,5) })
```
In version 4743 of _minigrace_, `ackermann(3,5)` executes 42439 method requests and takes around 17 ms, showing an execution speed of around 2400 requests/ms.

The normal implementation of method request is via the function `request` (defined in "js/gracelib.js"), which looks like this:

```
function request(obj, methname, ...args) {
    var origLineNumber = lineNumber;
    lineNumber = 0;                      // to avoid reporting line number in native code
    var returnTarget = invocationCount;  // will be incremented by invoked method
    var meth
    try {
        meth = obj.methods[methname];
        if (meth.confidential) {
            raiseConfidentialMethod(methname, obj);
        }
        var ret = meth.apply(obj, args);
    } catch(ex) {
        if (ex.exctype === 'return') {
            if (ex.target == returnTarget) {
                return ex.returnvalue;
            }
            throw ex;
        } else {
            return handleRequestException(ex, obj, methname, meth, args);
        }
    } finally {
        setLineNumber(origLineNumber);
    }
    return ret;
}
```
This function
 1. finds the requested method in the target object `ojb`'s `methods` object,
 2. checks if the requested method is confidential, by looking at the method function's `confidential` property.
 3. applies the method function to `obj` and the arguments.

A second function, `selfRequest`, does essentially the same thing, but omits the check for confidentiality.  The `selfRequest` function is used when compiling requests on self.

The functions `request` and `selfRequest` do all of this inside a `try…catch…finally`; if something goes wrong, and an exception is raised, the catch clause then figures out why.

There are three sorts of reasons that an exception might be raised.  The first is that somewhere inside `meth`, a Grace block needs to **return** to the context from which this request was made (or an enclosing context).  This is handled by the `(ex.exctype === 'return')` branch of the **if**.  The second is that the body of `meth` raises a Grace Exception.  The third is that something went wrong, usually that `obj` has no method `methname`.  Both of the last two cases are dealt with in `handleRequestException`; in the case of a Grace exception, this function also pushes a frame onto the exceptions `exitstack`, which (if  the exception is not handled) will be used for debugging.

Notice that there are no early returns, and no raised exceptions, in our definition of `ackermann(m,n)`, so we know that, for our benchmark program, the `try…catch` isn't necessary.  We can also omit to reset the line number in the `finally` clause — the lineNumber is used only for debugging.

The question that this experiment sets out to answer is: how much can we speed up the common case where the requested method exists, there is no early return, and no exception is raised.

## Module *ackermann_notry*

This version is the same as *ackermann_plain*, but redefines the `request` and `selfRequest` functions to omit the `try…catch` statement.  The intent is to see not just the raw cost of the `try…catch`, but also the implied cost in terms of the JIT-optimizations that are not performed because of it.

The way that we change `request` and `selfRequest` is to use a `native "js" code ‹…›` insert inside the module, which has the effect of redefining these functions *for this module only*.  The result is an approximately 50% speedup, to around 3790 requests/ms.

## Module *ackermann_inline*

The next question is: how much does it cost to put `request` and `selfRequest` in separate functions, rather than using line code to request a method.  I estimated this cost by hand-compiling a version of `ackermann` that inlined the bodies of the versions of `request` and `selfRequest` without the `try…catch`.  The inlined version contains the setting and resetting of the line numbers, and the testing for confidentiality.  The kernel of the inlined sequence for the request `n + 1` looks like this:

```
meth = var_n.methods["+(1)"];
if (meth.confidential) { raiseConfidentialMethod(methname, obj); }
var sum4 = meth.call(var_n, [1], new GraceNum(1));
```

This speeds things up to around 5800 requests/ms, or about 2.5 times the speed of the _plain_ version.

## Module *ackermann_nochecks*

If you look at the generated code JavaScript code, you will  see that it is studded with checks for `undefined`.  How much do these checks slow things down?  Not much; the results from
Module *ackermann_nochecks* are essentially the same to those from Module *ackermann_plain*.  This is probably because the V8 compiler is already removing these checks.  It therefore does not seem worthwhile expending a lot of effort to remove them from the generated code — although this would make the generated code smaller, which might have its own benefits.

## Module *ackermann\_oo\_inline*

Because the methods of a Grace object are not properties of the object itself, but instead properties of a separate `methods` object that is in turn a property of the object (or its prototype), we can't use the JavaScript `object.method` notation to request methods directly.  (I call this "OO style".) What is the cost of extracting a function from an ancillary object and then calling it, rather than using JavaScripts objects idiomatically?  To put it another way: if we were to move the methods onto the object itself, what would be the gain?

The module *ackermann\_oo\_inline* answers this question, by patching the objects in yet another `native "js" code ‹…›` insert to create a duplicate method reference.  (Note that all of these native code patches may not work for future versions of _minigrace_, which might generate different JavaScript code sequences.)  In this version, the same request of `n + 1` looks like this:

```
var sum4 = var_n["+(1)"]([1], new GraceNum(1));
```

The speedup for this version is significant: over 7600 requests/ms, 3.2 times better than the plain version.

Notice that the confidential checks are no longer being performed, because the method function is never made available directly.  We would need to find a new way of checking for confidential methods being invoked from outside.

## Could we use the OO form in production code?

I think that the answer to this question is "yes", but some problems have to be solved along the way.

 1. How to avoiding name clashes with JavaScript object properties? 
 2. How to perform confidentiality checks? 
 3. How to implement early returns?
 4. How to save and restore line numbers?
 5. How to deal with raised exceptions?
 6. How to deal with `NoSuchMethod` and undefined target errors?

### Avoiding Name Clashes

Prefix or suffix each Grace method name with a unique sigil, such as `_G_`, `𝒢` or `Ⓖ`.  (Putting symbols that are not easily typed at the end of the name would make using the debugger easier, because they would autocomplete.  Putting the sigil at the beginning has the advantage of placing the Grace methods together in an alphabetical listing.)  

### Confidentiality

Confidentiality is easily dealt with.  In addition to representing confidentiality as an attribute of the method function, we would also compile a check inside the method — if and only if the method is confidential.  We then make the first argument to the method a Boolean indicating whether the request is external (`true`) (corresponding to the current `request`), or on self (`false`)  (corresponding to the current `selfRequest`) .  Then, in confidential methods, raise an error if the first argument is false.

I'm suggesting that we use the first argument for this purpose because this position is currently occupied by the unused `argcv` parameter, which represents for the no-longer-used _argument count vector_.

When an alias is created, the alias is always confidential. This can be implemented by wrapping the method function in a _confidential wrapper_ function that checks that the first argument is `true`, and then calls the method function.  This is similar to the current scheme, where the wrapping function does nothing, but has a `confidential` property with value `true`.

### Early Returns

Early returns can be communicated using explicit return codes rather than exceptions.  These codes can be represented by augmenting the result object returned from the method with an additional property (`returnTo`), or by *wrapping* the returned object in an `earlyReturn` object (much as it is now wrapped in a `returnException`).

It would then be necessary to check the return code every time that a method returns.  For example:

```
var sum4 = var_n["+(1)"]([1], new GraceNum(1));
if (sum4.returnsTo) then {
    if (sum4.returnsTo == here) {
        sum4.returnsTo = undefined
    }
    return sum4
} 

```

If the return is to the current stack frame, the inline code must clear the return code (or remove the wrapper) and return; if it is to an enclosing stack frame, then the code just returns the augmented (or wrapped) object, which will be tested by the next request up the stack.

Note that the destination of a return *must* be a context that created a block object containing a **`return`** statement.  So the check can be simplified in many contexts, since they cannot be the target of the return.

The Pyret implementors have used a scheme like this; it is apparently less expensive than using exception handlers.
[Joe Gibbs Politz, Personal Communication]

### Saving and restoring line numbers

Restoring line numbers is easy; the compiler already knows the line number that applies following a method request, and can simply insert a `setLineNumber` call into the compiled code, with the correct numeral as argument.

The rationale for zeroing the line number before calling a method is that there are no `setLineNumber` requests inside hand-written method bodies.  Line number zero is used to suppress line number messages in the debugging output. This is actually unnecessary: such methods are already recognizable as being from native code; this should be sufficient to suppress line numbers from debugging output.

Thus, saving and restoring line numbers need not be a function of the `request` code sequence.

### Dealing with Exceptions

Removing the `try…catch` statement around every request actually makes this easier!  Now, an exception handler will exist in the JavaScript *only* where there is an exception handler in the Grace source code, so exceptions will propagate to the right place without any further ado.

### Dealing with `NoSuchMethod` and Undefined Target Exceptions

This may be the trickiest problem to solve. Fortunately the performance of this check is not important, if it can be moved out of the common case.  

If it were just a matter of trapping the error and producing a debugging stack trace, the best solution might be to let the JavaScript exception propagate to the top level, and then translate the JavaScript stack trace into a Grace stack trace.  JavaScript source-maps can help with this.

However, things aren't quite so simple. We also have to permit the association of code to handle `NoSuchMethod` exceptions inside an object using the _mirror_ method `whenNoMethodDo`.  Execution of this handler requires the target object and the name of the requested method, as well as the arguments; the result of the handler has to be used in place of the result of the normal method request. This implies that `NoSuchMethod` must be detected *before* the stack is unwound.

One approach would be to test for the presence of the method before each JavaScript method call, using code something like this:

```
if (var_n["+(1)"]) 
    var sum4 = var_n["+(1)"]([1], new GraceNum(1));
else
    var sum4 = dealWithNoMethod("+(1)", var_n, new GraceSequence(new GraceNum(1)));
```

Here `dealWithNoMethod` either invokes `var_n`'s no such method handler, or raises a `NoSuchMethod` exception.

An alternative would be to test for the existence of a `noSuchMethodHandler`, but this would still leave us the problem of pawing through the stack to report the `NoSuchMethod` exception.  Moreover, the above check is more easily optimized away, because the JavaScript engine must already check for the presence of a function of the correct name before executing it.

A real compiler could of course do some flow analysis and, in many cases, remove the check as unnecessary, because the target object would be known to possess the requested method.  

This explicit check, and the check on the return value, would cost us some fraction of the speedup obtained from inlining the request in the first place.  The question that remains is: how much?  A quick experiment (module *ackermann_oo_inline+methodCheck.grace*) shows that the existence check slows things down by less than 2%, which
is less than the variablility in our measurements.  Adding both ckecks actually speeding things up slightly (compared to the inlined oo-style calls with no checks), which shows, I think, that V8 is doing a great job removing these checks!

# Potential Wins

The file _results.txt_ summarizes the best case speedups that could possibly be obtained, since these small benchmarks do not generate any of the situations that trigger the branches.   However, this also the common case in real code.  It seems,  though, that without any major changes to the object representation, we could speed-up _minigrace_ from around 2300 requests/ms to 7000 requests/ms.
