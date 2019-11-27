import "sys" as sys

native "js" code ‹
    if (typeof performance == "undefined") {
        if (typeof window == "undefined")
            var performance = require('perf_hooks').performance;
        else
            var performance = window.performance;
    }
›

method now { 
    native "js" code ‹return new GraceNum(performance.now());›
}

method report(aBlock) {
    def startTime = now
    def startCount = sys.requestCount
    aBlock.apply
    def endTime = now
    def endCount = sys.requestCount
    def executionTime = endTime-startTime
    def executedRequests = endCount-startCount
    print "{executedRequests} requests in {executionTime} ms"
    print "{executedRequests / executionTime} requests/ms"
}

method time(aBlock) {
    def startTime = now
    aBlock.apply
    def endTime = now
    endTime-startTime
}

method benchmark(aBlock) {
    def limit = now + 10000
    def results = list.empty
    var n := 0
    var startTime
    var startCount
    do {
        startTime := now
        startCount := sys.requestCount
        aBlock.apply
    } while {
        results.addLast((sys.requestCount-startCount)@(now-startTime))
        now < limit
    }
    results
}

method withoutOutliers (sorted) {
    def n = sorted.size
    def lowerq = sorted.at((n/4).ceiling)
    def upperq = sorted.at((n*3/4).floor)
    def median = sorted.at((n/2).rounded)
    def iqr = upperq - lowerq
    def average = (sorted.fold {acc, each → acc + each } startingWith 0) / n
    def sd = ((sorted.fold {acc, each → acc + ((each - average)^2) } startingWith 0) / n ).sqrt
    def cutoff = (upperq - lowerq) * 1.5
    def outlierCount = sorted.fold {acc, each → acc + if (each > (upperq + cutoff)) then { 1 } else { 0 }} startingWith 0
    def lowOutlierCount = sorted.fold {acc, each → acc + if (each < (lowerq - cutoff)) then { 1 } else { 0 }} startingWith 0
    sorted.filter { each → each ≤ (upperq + 1.5 * iqr) } >> sequence
}
    

method summarize (stats) {
    // stats is a collection of count@time pairs
    var data 
    def requestCount = stats.first.x
    var filteredData := list.empty
    print "initially, {stats.size} executions of benchmark code"
    stats.do { each → 
        if (each.x ≠ requestCount) then {
            print "dropping {each}"
        } else {
            filteredData.add (each.y)
        }
    }
    filteredData.sort
    do { 
        data := filteredData
        filteredData := withoutOutliers(data) 
    } while {
         filteredData.size < data.size
    }
    
    def n = filteredData.size
    def average = (filteredData.fold {acc, each → acc + each } startingWith 0) / n
    def sd = ((filteredData.fold {acc, each → acc + ((each - average)^2) } startingWith 0) / n ).sqrt
    def outlierCount = filteredData.fold {acc, each → acc + if (each > (average + 2.5 * sd)) then { 1 } else { 0 }} startingWith 0
    def lowOutlierCount = filteredData.fold {acc, each → acc + if (each < (average - 2.5 * sd)) then { 1 } else { 0 }} startingWith 0
    def lowerq = filteredData.at((n/4).ceiling)
    def upperq = filteredData.at((n*3/4).floor)
    def median = filteredData.at((n/2).rounded)
    print "after removing outliers, n = {n}; standard deviation (σ) = {sd}; {outlierCount} measurements > 2.5 σ above mean"
    if (lowOutlierCount ≠ 0) then {
        print "{lowOutlierCount} < 2.5 σ below mean"
    }
    print "average = {average}, quartiles = [{filteredData.first}, {lowerq}, {median}, {upperq}, {filteredData.last}]; iqr = {upperq - lowerq}"
    print "median result: {requestCount} requests in {median} ms = {(requestCount/median).rounded} requests/ms"
}
    