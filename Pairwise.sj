//USEUNIT JSON (basically a copy of Crockfords json2.js)
//conversion of the java code from http://www.mcdowella.demon.co.uk/allPairs.html

function generateTests() { 
    var MSExcel = Sys.OleObject("excel.application");
    var row = 1;
    var col;
    var conditions = [];
    
    var paramValue;
    while (MSExcel.Cells(row, 1).Text) {
        var paramValues = [];
        col = 1;
        while ((paramValue = MSExcel.Cells(row, col++).Text) !== "") {
            paramValues.push(paramValue);
        }         
        conditions.push(paramValues);
        row++;
    } 
    Log.Message(JSON.stringify(conditions));
    var pairs = pairup(conditions); 
    var testCases = pairs.cases;
    var paramNames = pairs.parameters; 
    var testCase;
    MSExcel.Cells(++row, 1).Value = "Test Cases (" + testCases.length + ")";
    for (var i = 0, l = paramNames.length; i < l; i++) {
        MSExcel.Cells(row, i + 2).Value = paramNames[i];
    }
    for (var i = 0, l = testCases.length; i < l; i++) {
        MSExcel.Cells(++row, 1).Value = i;
        testCase = testCases[i];
        for (var j = 0, m = testCase.length; j < m; j++) {
            MSExcel.Cells(row, j + 2).Value = testCase[j];
        }    
    }
}
function pairup() {
    var numberParameters = 0;
    var numberParameterValues = 0;
    var numberPairs = 0;
    var poolSize = 60; // number of candidate testSet arrays to generate before picking one to add to testSets List

    var legalValues = []; // in-memory representation of input file as ints
    var parameterValues = []; // one-dimensional array of all parameter values
    var allPairsDisplay = []; // rectangular array; does not change, used to generate unusedCounts array
    var unusedPairs = []; // changes
    var unusedPairsSearch = []; // square array -- changes
    var parameterPositions = []; // the parameter position for a given value
    var unusedCounts = []; // count of each parameter value in unusedPairs List
    var testSets = []; // the main result data structure
    conditions = arguments[0] || [ //default for debugging algorithm
		["Param0", "a", "b"],
		["Param1", "c", "d", "e", "f"],
		["Param2", "g", "h", "i"],
		["Param3", "j", "k"]
    ];
    //seems to be most efficient when parameters are sorted by lowest weight
    conditions.sort(function(a, b) {
        return a.length - b.length;
    }); 
	Log.Message("Begin pair-wise testset generation");
	numberParameters = conditions.length;
	var currRow = 0;
	var kk = 0; // points into parameterValues
	var values = [];
	var strValues = [];
    var paramNames = [];
	for (var i = 0; i < numberParameters; i++) {
		numberParameterValues += conditions[i].length - 1;
		values = [];
		strValues = conditions[i];
		paramNames.push(strValues.splice(0, 1));
		for (var j = 0, l = strValues.length; j < l; j++) {
			values[j] = kk;
			parameterValues[kk] = strValues[j];
			++kk;
		}
		legalValues[currRow++] = values;
	}
	Log.Message("There are " + numberParameters + " parameters");
	Log.Message("There are " + numberParameterValues + " parameter values");
	Log.Message("Parameter values: ");
	Log.Message(JSON.stringify(parameterValues));
	//Log.Message("\nLegal values internal representation: ");
	//Log.Message(JSON.stringify(legalValues));
	var lvl = legalValues.length;
//    	Log.Message("There are " + numberPairs + " pairs ");
	// process the legalValues array to populate the allPairsDisplay & unusedPairs & unusedPairsSearch collections
	//allPairsDisplay = new int[numberPairs, 2]; // rectangular array; does not change
	//unusedPairs = new List<int[]>(); // List of pairs which have not yet been captured
	//unusedPairsSearch = new int[numberParameterValues, numberParameterValues]; // square array -- changes

	var currPair = 0;
	for (var i = 0; i <= lvl - 2; ++i) {
		for (var j = i + 1; j <= lvl - 1; ++j) {
            numberPairs += (legalValues[i].length * legalValues[j].length);
			var firstRow = legalValues[i];
			var secondRow = legalValues[j];
			for (var x = 0, fl = firstRow.length; x < fl; ++x) {
				for (var y = 0, sl = secondRow.length; y < sl; ++y) {
					allPairsDisplay[currPair] = [firstRow[x], secondRow[y]];
					unusedPairs.push([firstRow[x], secondRow[y]]);
					unusedPairsSearch[firstRow[x]] = unusedPairsSearch[firstRow[x]] || [];
					unusedPairsSearch[firstRow[x]][secondRow[y]] = 1;
					++currPair;
				} // y
			} // x
		} // j
	} // i
	Log.Message("There are " + numberPairs + " pairs ");
    //Log.Message(JSON.stringify(unusedPairsSearch));

	// process legalValues to populate parameterPositions array
	//parameterPositions = new int[numberParameterValues]; 
    // the indexes are parameter values, the cell values are positions within a testSet
	var k = 0;  // points into parameterPositions
	for (var i = 0; i < lvl; ++i) {
		var curr = legalValues[i];
		for (var j = 0, cl = curr.length; j < cl; ++j) {
			parameterPositions[k++] = i;
		}
	}

	// process allPairsDisplay to determine unusedCounts array
	//unusedCounts = new int[numberParameterValues];  
    // inexes are parameter values, cell values are counts of how many times the parameter value apperas in the unusedPairs collection
	for (var i = 0, apdl = allPairsDisplay.length; i < apdl; ++i) {
		unusedCounts[allPairsDisplay[i][0]] = unusedCounts[allPairsDisplay[i][0]] || 0;
		++unusedCounts[allPairsDisplay[i][0]];
		unusedCounts[allPairsDisplay[i][1]] = unusedCounts[allPairsDisplay[i][1]] || 0;
		++unusedCounts[allPairsDisplay[i][1]];
	}

	//==============================================================================================================
	//testSets = new List<int[]>();  // primary data structure
	Log.Message("Computing testsets which capture all possible pairs . . .");
	while (unusedPairs.length) {// as long as ther are unused pairs to account for . . .
		var candidateSets = [];//new int[poolSize][]; // holds candidate testSets
		for (var candidate = 0; candidate < poolSize; ++candidate) {
			var testSet = [];//new int[numberParameters]; // make an empty candidate testSet
			// pick "best" unusedPair -- the pair which has the sum of the most unused values
			var bestWeight = 0;
			var indexOfBestPair = 0;
			for (var i = 0; i < unusedPairs.length; ++i) {
				var curr = unusedPairs[i];
				var weight = unusedCounts[curr[0]] + unusedCounts[curr[1]];
				if (weight > bestWeight) {
					bestWeight = weight;
					indexOfBestPair = i;
				}
			}
			var best = unusedPairs[indexOfBestPair];
//			Log.Message("Best pair is " + best[0] + ", " + best[1] + " at " + indexOfBestPair + " with weight " + bestWeight);
			var firstPos = parameterPositions[best[0]]; // position of first value from best unused pair
			var secondPos = parameterPositions[best[1]];
		//	Log.Message("The best pair belongs at positions " + firstPos + " and " + secondPos);
			// generate a random order to fill parameter positions
			var ordering = [];//new int[numberParameters];
			for (var i = 0; i < numberParameters; ++i) {// initially all in order
				ordering[i] = i;
			}
			// put firstPos at ordering[0] && secondPos at ordering[1]
			ordering[0] = firstPos;
			ordering[firstPos] = 0;
			var t = ordering[1];
			ordering[1] = secondPos;
			ordering[secondPos] = t;
			// reverse ordering[2] thru ordering[last]
            // on alternate candidates to smooth out selection of sub values
            if (candidate % 2) {
                var shuffle = ordering.splice(2, ordering.length - 2);//note JScript requires 2nd parameter to return a result from splice()
                shuffle.reverse();
                ordering = ordering.concat(shuffle);
            }

			// place two parameter values from best unused pair into candidate testSet
			testSet[firstPos] = best[0];
			testSet[secondPos] = best[1];
			// for remaining parameter positions in candidate testSet, try each possible legal value, picking the one which captures the most unused pairs . . .
			for (var i = 2; i < numberParameters; ++i) {// start at 2 because first two parameter have been placed
				var currPos = ordering[i];
				var possibleValues = legalValues[currPos];
				var currentCount = 0;  // count the unusedPairs grabbed by adding a possible value
				var highestCount = 0;  // highest of these counts
				var bestJ = 0;         // index of the possible value which yields the highestCount
				for (var j = 0, pvl = possibleValues.length; j < pvl; ++j) {// examine pairs created by each possible value and each parameter value already there
					currentCount = 0;
					for (var p = 0; p < i; ++p) {  // parameters already placed
						var candidatePair = [possibleValues[j], testSet[ordering[p]]];
                        try {
							if ((unusedPairsSearch[candidatePair[0]][candidatePair[1]] === 1) || 
								(unusedPairsSearch[candidatePair[1]][candidatePair[0]] === 1)) {  // because of the random order of positions, must check both possibilities
								++currentCount;
							//} else {
							//Log.Message("Did NOT find " + candidatePair[0] + "," + candidatePair[1] + " in unusedPairs");
							}
                        } catch (e) {
                        }
					} // p -- each previously placed paramter
					if (currentCount > highestCount) {
						highestCount = currentCount;
						bestJ = j;
					}
				} // j -- each possible value at currPos
				testSet[currPos] = possibleValues[bestJ]; // place the value which captured the most pairs
			} // i -- each testSet position 
			candidateSets[candidate] = testSet;  // add candidate testSet to candidateSets array
		} // for each candidate testSet
		// Iterate through candidateSets to determine the best candidate
		var indexOfBestCandidate = 0;//Math.floor(r * candidateSets.length);// r.Next(candidateSets.Length); // pick a random index as best
		var mostPairsCaptured = NumberPairsCaptured(candidateSets[indexOfBestCandidate], unusedPairsSearch);
		for (var i = 0, csl = candidateSets.length; i < csl; ++i) {
			var pairsCaptured = NumberPairsCaptured(candidateSets[i], unusedPairsSearch);
			if (pairsCaptured > mostPairsCaptured) {
				mostPairsCaptured = pairsCaptured;
				indexOfBestCandidate = i;
			}
		}
		var bestTestSet = candidateSets[indexOfBestCandidate];
        //Log.Message(JSON.stringify(bestTestSet));
		testSets.push(bestTestSet);// Add the best candidate to the main testSets List
		// now perform all updates
		//Log.Message("Updating unusedPairs");
		//Log.Message("Updating unusedCounts");
		//Log.Message("Updating unusedPairsSearch");
		for (var i = 0; i <= numberParameters - 2; ++i) {
			for (var j = i + 1; j <= numberParameters - 1; ++j) {
				var v1 = bestTestSet[i]; // value 1 of newly added pair
				var v2 = bestTestSet[j]; // value 2 of newly added pair
				//Log.Message("Decrementing the unused counts for " + v1 + " and " + v2);
				unusedCounts[v1]--;
				unusedCounts[v2]--;
				//Log.Message("Setting unusedPairsSearch at " + v1 + " , " + v2 + " to 0");
				unusedPairsSearch[v1][v2] = 0;
				for (var p = 0; p < unusedPairs.length; ++p) {
					var curr = unusedPairs[p];
					if ((curr[0] === v1) && (curr[1] === v2))	{
						//Log.Message("Removing " + v1 + ", " + v2 + " from unusedPairs List");
						unusedPairs.splice(p, 1);//RemoveAt(p);
					}
				}
			} // j
		} // i
		//Log.Message("Best pair is " + best[0] + ", " + best[1] + " at " + indexOfBestPair + " with weight " + bestWeight);
        //Log.Message(JSON.stringify(unusedCounts));

	} // primary while loop
	// Display results
	Log.Message("Result testsets: " + testSets.length);
	//Log.Message(JSON.stringify(testSets));
    var testCases = [];
    var testCase;
	for (var i = 0, tsc = testSets.length; i < tsc; ++i) {
		var curr = testSets[i];
		var val$ = [i + ": "];
        testCase = [];
		for (var j = 0; j < numberParameters; ++j) {
			val$.push(parameterValues[curr[j]]);
            testCase.push(parameterValues[curr[j]]);
		}
        testCases.push(testCase);
		Log.Message(val$.join(" "));
	}
	//Log.Message(JSON.stringify(allPairsDisplay));
	Log.Message("End");
  //return parameter names as they have been sorted
  return {"cases": testCases, "parameters": paramNames};
}

function NumberPairsCaptured(ts, unusedPairsSearch) {
	var ans = 0;
	for (var i = 0, l = ts.length; i <= (l - 2); ++i) {
		for (var j = i + 1; j <= (l - 1); ++j) {
			if (unusedPairsSearch[ts[i]][ts[j]] === 1) {
				++ans;
			}
//            try {
//    			if (unusedPairsSearch[ts[i]][ts[j]] === 1) {
//    				++ans;
//	    		}
//            } catch (e) {
//            }
		}
	}
	return ans;
}
