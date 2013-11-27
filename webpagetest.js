var WPT = {
    "host": "<IP of private instance of webpagetest>",
    SETTINGS: {//can be overriden
        "bwDown": "0",//bandwidth down
        "bwUp": "0",//bandwidth up
        "latency": "0",
        "plr": "0",//packet loss rate
        "runs": "1",
        "&fvonly": "1",//first view only
        "f": "json",
        "video": "1",//record video for timelines and comparisons
        "label": ""
    },    
    GET: function WD_GET(page, parms) {
        var testURL = [];
        for (var parm in this.SETTINGS) {
            testURL.push(parm + "=" + this.SETTINGS[parm]);
        }
        for (var parm in parms) {
            testURL.push(parm + "=" + parms[parm]);
        }
        testURL = "http://" + this.host + "/" + page + "?" + testURL.join("&");
    		var options = {
    			"url": testURL,
    			"headers": {"content-type": "application/json"},
    			"method": "GET"
    		}
		    return WD.request(options);//from webdriver.js
    },
    RUNTEST: function WPT_RUNTEST(testScript) {
        return this.GET("runtest.php", {
            "url": "<site to test>",
            "browser": "<browser on wpt agent>",
            "location": "<agent location>",
            "r": +(new Date()),//force a new test run
            "script": //convert to tab-separated, uri-encoded
                MAP(testScript, function (scriptLine) {
                    return encodeURIComponent(scriptLine).replace(/(\%20){2,4}/g, "%09");
                }).join("%0A")            
        });
              
    }

}
//
// examples
//
function TEST_latency() {//test effect of latency on hitting landing page
    WPT.SETTINGS["runs"] = 2;//to get an average
    WPT.SETTINGS["bwDown"] = "4000";
    WPT.SETTINGS["bwUp"] = "500";
    WPT.SETTINGS["latency"] = "300";
    WPT.SETTINGS["label"] = "300ms latency";

    var testdetails = WPT.RUNTEST([
        "navigate   http://www.blahblahblah.com/login"
    ]);
    Log.Message(testdetails.data.userUrl);//the results page (with latency)

    WPT.SETTINGS["latency"] = "00";
    WPT.SETTINGS["label"] = "zero latency";

    testdetails = WPT.RUNTEST([
        "navigate   http://www.blahblahblah.com/foobar"
    ]);
    Log.Message(testdetails.data.userUrl);//results without latency - compare via the test history page
}

function TEST_LogIn_and_Chart() {//login and click some links - only record the chart generation step
    var testdetails = WPT.RUNTEST([
        "logData    0",
        "setViewportSize    1650    850",
        "navigate   http://www.blahblahblah.com/login",
        "setValue   id=username     bbbuser",
        "setvalue   id=password   bbbpwd",
        "clickAndWait   id=signIn",
        "click	innerText=Variance",
        "click	innerText=Time",
        "click	innerText=New York",
        "logData	1",
        "setDOMRequest    metric=variance",
        "clickAndWait	id=update"
    ]);
    Log.Message(testdetails.data.userUrl);
}
