var parameterNames = [];
var pairCount = 0;
var poolSize = 3; // number of candidate testSet arrays to generate before picking one to add to testSets List

var parameterValues = []; // one-dimensional array of all parameter values
var allPairsDisplay = []; // rectangular array; does not change, used to generate unusedCounts array
var unusedPairs = []; // changes
var unusedPairsSearch = []; // square array -- changes
var testSets = []; // the main result data structure

var conditions = [
// 	["Testing", "1", "2", "3"],
// 	["RainbowColours", "red", "orange", "yellow", "green", "blue", "indigo", "violet"],
// 	["Rainbow", "George", "Geoffrey", "Bungle", "Zippy"],
// 	["Well", "yes", "no"]
// ];
["Redundancy", "P0", "P1", "P99", "P100", "P101", "N0", "N-", "N=", "N+"],
["Strategy", "S", "E"],
["Trigger Load", "0", "75", "100", "101"],
["Groupsize", "0", "1", "2", "8", "999"],
["ZeroLoad", "Y", "N"],
["Chart", "L", "E", "DS"],
["Idle State", "Off", "Idle", "On"],
["Standby", "Off", "Idle", "On"],
["Passive", "Off", "Idle", "On"]
];
conditions.sort(function (a,b) {//most efficient with lowest weight first
    return a.length - b.length;
});
var parameterCount = conditions.length;

console.log("\nBegin pair-wise testset generation\n");
//console.log("\nInput file = " + file + "\n");

var allPairs = [];
var currPair = 0;
var parameterValueSets = getParameterValueSets();
processParameterValueSets();

var parameterPositions = getParameterPositions(); // the parameter position for a given value

var unusedCounts = getUnusedCounts(); // count of each parameter value in unusedPairs List

getTestSets();

//==================================================================================
function getParameterValueSets() {
	var numberParameterValues = 0;
	var parameterIndex = 0;
	function updateParameters (parameterValue) {
		parameterValues[parameterIndex] = parameterValue;
		numberParameterValues++;
		return parameterIndex++;
	}
	var parameterValueSets = conditions.map(function (conditionSet){
		parameterNames.push(conditionSet.splice(0, 1)[0]);
		return conditionSet.map(updateParameters);
	});
	console.log("There are " + parameterCount + " parameters");
	console.log("There are " + numberParameterValues + " parameter values");
	console.log("\nParameter values: ");
	console.log(JSON.stringify(parameterValues));
	console.log("");
	console.log("\nLegal values internal representation: ");
	console.log(JSON.stringify(parameterValueSets));
	return parameterValueSets;
}
//==================================================================================	
function buildPairs (groupIndex, pairIndex) {
	parameterValueSets[groupIndex].forEach(function (groupItem) {
        allPairs[groupItem] = allPairs[groupItem] || {"group": pairIndex, "count": 0, "pairs": []};
		parameterValueSets[pairIndex].forEach(function (pairItem){
	        allPairs[pairItem] = allPairs[pairItem] || {"group": pairIndex, "count": 0, "pairs": []};
			allPairsDisplay[currPair] = [groupItem, pairItem];
			unusedPairs.push([groupItem, pairItem]);
			unusedPairsSearch[groupItem] = unusedPairsSearch[groupItem] || [];
			unusedPairsSearch[groupItem][pairItem] = 1;
	        allPairs[groupItem].pairs.push(pairItem);
	        allPairs[groupItem].count++;
	        allPairs[pairItem].count++;
			++currPair;
		});
	});
}
function buildGroup(groupIndex) {
	for (var pairIndex = groupIndex + 1; pairIndex <= parameterCount - 1; ++pairIndex) {
        pairCount += (parameterValueSets[groupIndex].length * parameterValueSets[pairIndex].length);
		buildPairs(groupIndex, pairIndex);
	}
}
function processParameterValueSets () {
// process the parameterValueSets array to populate the allPairsDisplay & unusedPairs & unusedPairsSearch collections
	for (var groupIndex = 0; groupIndex <= parameterCount - 2; ++groupIndex) {
		buildGroup(groupIndex);
	} // i
    console.log("\nThere are " + pairCount + " pairs ");
    console.log(JSON.stringify(allPairs));
    console.log(JSON.stringify(allPairsDisplay));
    //console.log(JSON.stringify(unusedPairs));
    //console.log(JSON.stringify(unusedPairsSearch));
}
//==================================================================================
function getParameterPositions () {
	var parameterPositions = [];
	var k = 0;  
	parameterValueSets.forEach(function (parameterValueSet, i) {
		parameterValueSet.forEach(function (parameterValueItem) {
			parameterPositions[k++] = i;
		});
	});
    console.log(JSON.stringify("parameterPositions"));
    console.log(JSON.stringify(parameterPositions));
    return parameterPositions;
}
//==================================================================================
function getUnusedCounts () {
	// process allPairsDisplay to determine unusedCounts array
	var unusedCounts = [];
	for (var i = 0, apdl = allPairsDisplay.length; i < apdl; ++i) {
		unusedCounts[allPairsDisplay[i][0]] = unusedCounts[allPairsDisplay[i][0]] || 0;
		++unusedCounts[allPairsDisplay[i][0]];
		unusedCounts[allPairsDisplay[i][1]] = unusedCounts[allPairsDisplay[i][1]] || 0;
		++unusedCounts[allPairsDisplay[i][1]];
	}
    console.log(JSON.stringify("unusedCounts"));
    console.log(JSON.stringify(unusedCounts));
    return unusedCounts;
}
//==================================================================================
function shuffleCandidates (candidate, firstPos, secondPos) {
// generate a shuffled order to fill parameter positions
	var ordered = conditions.map(function (d, i){
		return i;
	});
	ordered[0] = firstPos;
	ordered[firstPos] = 0;
	var t = ordered[1];
	ordered[1] = secondPos;
	ordered[secondPos] = t;
    //console.log(JSON.stringify(ordered));
	//// shuffle ordered[2] thru ordered[last]
    if (candidate % 2) {
        var shuffle = ordered.splice(2);
        shuffle.reverse();
        ordered = ordered.concat(shuffle);
    }
    //console.log("*R*" + JSON.stringify(ordered));
    return ordered;
}
function getConditionWithMostPairs(possibleValues, orderedIndex, testSet, ordered) {
	var currentCount = 0;  // count the unusedPairs grabbed by adding a possible value
	var highestCount = 0;  // highest of these counts
	var bestPossibleValue = possibleValues[0];
	possibleValues.forEach(function (possibleValue) {
		currentCount = 0;
		for (var p = 0; p < orderedIndex; ++p) {  // parameters already placed
			var candidatePair = [possibleValue, testSet[ordered[p]]];
            try {
                if ((unusedPairsSearch[candidatePair[0]][candidatePair[1]] === 1) || 
					(unusedPairsSearch[candidatePair[1]][candidatePair[0]] === 1)) {  
					// because of the randomish order of positions, must check both possibilities
                    ++currentCount;
                }
            } catch (e) {//may not be anything at that position, so ignore any error
            }
		} // p -- each previously placed paramter
		if (currentCount > highestCount) {
			highestCount = currentCount;
			bestPossibleValue = possibleValue;
		}
	});
	return bestPossibleValue;
} 
function getCandidateSets () {
	var candidateSets = [];// holds candidate testSets
	for (var candidate = 0; candidate < poolSize; ++candidate) {
		var testSet = [];// make an empty candidate testSet
		var bestPair = unusedPairs.sort(function (a, b){
			return ((unusedCounts[a[0]] + unusedCounts[a[1]]) - (unusedCounts[b[0]] + unusedCounts[b[1]]));
		})[0];
//			console.log("Best pair is " + best[0] + ", " + best[1] + " at " + indexOfBestPair + " with weight " + bestWeight);
		var firstPos = parameterPositions[bestPair[0]]; // position of first value from best unused pair
		var secondPos = parameterPositions[bestPair[1]];
		testSet[firstPos] = bestPair[0];
		testSet[secondPos] = bestPair[1];
	//	console.log("The best pair belongs at positions " + firstPos + " and " + secondPos);
		var ordered = shuffleCandidates(candidate, firstPos, secondPos);
		// place two parameter values from best unused pair into candidate testSet
		// for remaining parameter positions in candidate testSet, 
		//try each possible legal value, picking the one which captures the most unused pairs . . .
		for (var i = 2; i < parameterCount; ++i) {// start at 2 because first two parameter have been placed
			testSet[ordered[i]] = getConditionWithMostPairs(parameterValueSets[ordered[i]], i, testSet, ordered);
		}
		candidateSets[candidate] = testSet;  // add candidate testSet to candidateSets array
	} // for each candidate testSet}
	return candidateSets;
}
function countPairsCaptured(ts, unusedPairsSearch) {
	var pairsCaptured = 0;
	for (var i = 0, l = ts.length; i <= (l - 2); ++i) {
		for (var j = i + 1; j <= (l - 1); ++j) {
			if (unusedPairsSearch[ts[i]][ts[j]] === 1) {
				++pairsCaptured;
			}
		}
	}
	return pairsCaptured;
}
function getBestCandidate (candidateSets) {
// Iterate through candidateSets to determine the best candidate
	var bestCandidate = candidateSets[0];
	var mostPairsCaptured = countPairsCaptured(bestCandidate, unusedPairsSearch);
	candidateSets.forEach(function (candidateSet){
		var pairsCaptured = countPairsCaptured(candidateSet, unusedPairsSearch);
		if (pairsCaptured > mostPairsCaptured) {
			mostPairsCaptured = pairsCaptured;
			bestCandidate = candidateSet;
		}
	});
	return bestCandidate;
}
function removeUnusedPairs (v1, v2) {
	unusedPairs.forEach(function (unusedPair, p) {
		if ((unusedPair[0] === v1) && (unusedPair[1] === v2))	{
			//console.log("Removing " + v1 + ", " + v2 + " from unusedPairs List[" + p + "]");
			unusedPairs.splice(p, 1);
		}
	});
}
function updateUnusedPairs (bestTestSet) {
	for (var i = 0; i <= parameterCount - 2; ++i) {
		for (var j = i + 1; j <= parameterCount - 1; ++j) {
			var v1 = bestTestSet[i]; // value 1 of newly added pair
			var v2 = bestTestSet[j]; // value 2 of newly added pair
			//console.log("Decrementing the unused counts for " + v1 + " and " + v2);
			unusedCounts[v1]--;
			unusedCounts[v2]--;
			//console.log("Setting unusedPairsSearch at " + v1 + " , " + v2 + " to 0");
			unusedPairsSearch[v1][v2] = 0;
			removeUnusedPairs(v1, v2);
		} // j
	} // i
}
function getTestCases () {
    var testCases = [];
    var testCase;
    var testCondition;
    var paramName;
    testSets.forEach(function (testSet, i) {
		var val$ = [i + ": "];
        testCase = [];
        conditions.forEach(function (condition, c) {
			val$.push(parameterValues[testSet[c]]);
            paramName = parameterNames[c];
            testCondition = {};
            testCondition[paramName] = parameterValues[testSet[c]];
            testCase.push(testCondition);
        });
        testCases.push(testCase);
		console.log(val$.join(" "));
    });
	return testCases;
}
function getTestSets () {
	console.log("\nComputing testsets which capture all possible pairs . . .");
	while (unusedPairs.length) {// as long as there are unused pairs to account for . . .
        var bestTestSet = getBestCandidate(getCandidateSets());
		testSets.push(bestTestSet);// Add the best candidate to the final testSets List
        updateUnusedPairs(bestTestSet);
	}
	// Display results
	console.log("\nResult testsets: \n");
	console.log(JSON.stringify(testSets));
    var testCases = getTestCases();
	//console.log(JSON.stringify(allPairsDisplay));
    console.log(JSON.stringify(testCases));
    console.log("");
    console.log(testSets.length + " test cases produced");
	
	var minPairs = ((conditions[parameterCount - 1].length) * (conditions[parameterCount - 2].length));
    console.log("Efficiency ratio: " + Math.floor(100 * minPairs / testSets.length) + "%");
    console.log("\nEnd\n");
}