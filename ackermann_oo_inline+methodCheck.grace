dialect "minispec"
import "performance" as performance

//        lineNumber = 0;                      // to avoid reporting line number in native code
//        var returnTarget = invocationCount;  // will be incremented by invoked method
//        var meth = obj.methods[methname];
//        if (meth.confidential) { raiseConfidentialMethod(methname, obj); }
//        var ret = meth.apply(obj, args);
//        setLineNumber(origLineNumber);


method ackermann(m, n) {
    native "js" code ‹
        if (var_m["==(1)"]) var opresult3 = var_m["==(1)"]([1], new GraceNum(0)); else throw new GraceExceptionPacket(NoSuchMethodObject, someMethodName); 
        if (Grace_isTrue(opresult3)) {
          setLineNumber(7);    // compilenode num
          var origLineNumber = lineNumber;
          lineNumber = 0;
          if (var_n["+(1)"]) var sum4 = var_n["+(1)"]([1], new GraceNum(1)); else throw new GraceExceptionPacket(NoSuchMethodObject, someMethodName); 
          setLineNumber(origLineNumber);
          if2 = sum4;
        } else {
          var if5 = GraceDone;
          setLineNumber(26);    // compilenode num
          origLineNumber = lineNumber;
          lineNumber = 0;
          if (var_n["==(1)"]) var opresult6 = var_n["==(1)"]([1], new GraceNum(0)); else throw new GraceExceptionPacket(NoSuchMethodObject, someMethodName); 
          setLineNumber(origLineNumber);
          if (Grace_isTrue(opresult6)) {
            setLineNumber(34);    // compilenode num
            origLineNumber = lineNumber;
            lineNumber = 0;
            if (var_m["-(1)"]) var diff8 = var_m["-(1)"]([1], new GraceNum(1)); else throw new GraceExceptionPacket(NoSuchMethodObject, someMethodName); 
            setLineNumber(origLineNumber);
            // call case 1: outer request
            origLineNumber = lineNumber;
            lineNumber = 0;
            if (var_$module["ackermann(2)"]) var call7 = var_$module["ackermann(2)"]([2], diff8, new GraceNum(1)); else throw new GraceExceptionPacket(NoSuchMethodObject, someMethodName); 
            setLineNumber(origLineNumber);
            if5 = call7;
          } else {
            setLineNumber(21);    // compilenode num
            origLineNumber = lineNumber;
            lineNumber = 0;
            if (var_m["-(1)"]) var diff10 = var_m["-(1)"]([1], new GraceNum(1)); else throw new GraceExceptionPacket(NoSuchMethodObject, someMethodName); 
            setLineNumber(origLineNumber);
            origLineNumber = lineNumber;
            lineNumber = 0;
            if (var_n["-(1)"]) var diff12 = var_n["-(1)"]([1], new GraceNum(1)); else throw new GraceExceptionPacket(NoSuchMethodObject, someMethodName); 
            setLineNumber(origLineNumber);
            // call case 1: outer requestorigLineNumber = lineNumber;
            lineNumber = 0;
            if (var_$module["ackermann(2)"]) var call11 = var_$module["ackermann(2)"]([2], var_m, diff12); else throw new GraceExceptionPacket(NoSuchMethodObject, someMethodName); 
            setLineNumber(origLineNumber);
            // call case 1: outer request
            origLineNumber = lineNumber;
            lineNumber = 0;
            if (var_$module["ackermann(2)"]) var call9 = var_$module["ackermann(2)"]([2], diff10, call11); else throw new GraceExceptionPacket(NoSuchMethodObject, someMethodName); 
            setLineNumber(origLineNumber);
            if5 = call9;
          }
          if2 = if5;
        }
        return if2;
    ›
}

native "js" code ‹
    GraceNum.prototype["==(1)"] = GraceNum.prototype.methods["==(1)"];
    GraceNum.prototype["+(1)"] = GraceNum.prototype.methods["+(1)"];
    GraceNum.prototype["-(1)"] = GraceNum.prototype.methods["-(1)"];
    GraceNum.prototype["==(1)"] = GraceNum.prototype.methods["==(1)"];
    var_$module["ackermann(2)"] = var_$module.methods["ackermann(2)"];
›

describe "ackermann on small known values" with {
    specify "A(1,2)" by {
        expect (ackermann(1,2)) toBe 4
    }
    specify "A(3,2)" by {
        expect (ackermann(3,2)) toBe 29
        expect (ackermann(3,2)) toBe (a3(2))
    }
    specify "A(3,4)" by {
        expect (ackermann(3,4)) toBe 125
        expect (ackermann(3,4)) toBe (a3(4))
    }
    specify "A(4,0)" by {
        expect (ackermann(4,0)) toBe 13
    }
}

method a3(n) {
    // computes ackermann(3, n)
    (2^(n+3)) - 3
}

performance.summarize(performance.benchmark{ ackermann(3,5) })
