dialect "minispec"
import "performance" as performance

method ackermann(m, n) {
    if (m == 0) then { 
        n + 1 
    } elseif { n == 0 } then {
        ackermann(m-1, 1)
    } else {
        ackermann(m-1, ackermann(m, n - 1))
    }
}

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

native "js" code ‹
    function request(obj, methname, ...args) {
        var origLineNumber = lineNumber;
        lineNumber = 0;                      // to avoid reporting line number in native code
        var returnTarget = invocationCount;  // will be incremented by invoked method
        var meth = obj.methods[methname];
        if (meth.confidential) { raiseConfidentialMethod(methname, obj); }
        var ret = meth.apply(obj, args);
        setLineNumber(origLineNumber);
        return ret;
    }

    request.isGraceRequest = true;  // marks this as a request dispatch

    function selfRequest(obj, methname, ...args) {
        var origLineNumber = lineNumber;
        lineNumber = 0;                      // to avoid reporting line number in native code
        var returnTarget = invocationCount;  // will be incremented by invoked method
        var meth = obj.methods[methname];
        var ret = meth.apply(obj, args);
        setLineNumber(origLineNumber);
        return ret;
    }
    selfRequest.isGraceRequest = true;  // marks this as a request dispatch
›
