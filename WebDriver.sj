//USEUNIT JSON (Crockford's json2.js plus the Array Map method from MDN

var WD = {
    setup: {"desiredCapabilities": {
        "browserName": "internet explorer"
    }},
    host: "<machine IP webdriver is running on>",
    port: 4444,//80,
    XHR: null,
    delay: 5e3,
    
    request: function WD_REQUEST(options) {
        //handle GETS and POSTS
        //return the JSON response or null for stale objects
        var response;
        var XmlHttpRequest = Sys["OleObject"]("MSXML2.XMLHTTP.3.0");
        XmlHttpRequest.open(options.method, options.url, false); 
        XmlHttpRequest.setRequestHeader("Connection","keep-alive");
        for (var header in options.headers) {
            XmlHttpRequest.setRequestHeader(header, options.headers[header]);
        }
        try {
            XmlHttpRequest.send(options.body);
        } catch (e) {
            //may never escape on Win8 IE10/11 - use with caution
            while (XmlHttpRequest.readyState < 4) {
                Delay(1e3);
            }
        }
        try {
            response = XmlHttpRequest.responseText; 
            if (response) {
                response = JSON.parse(response);
            }
        } catch (e) {
            response = "Error";
        }     
        XmlHttpRequest = null;
        if (response.status) {
            var errmsg = response.value.message || response.value;
            if (errmsg.match(/stale/)) {
                return null;
            } 
            Log.Error(errmsg);
        }
        return response;
    },    
    
    POST: function WD_POST(path, body) {
        //direct the POST to the webdriver host
        //add the session id after the initial setup
        if (typeof path !== "string") {
            body = path;
            path = "";
        }
        body = (typeof body === "object") ? (JSON.stringify(body || "")) : body;
		var options = {
			"url":  path.match(/^http/) ? path : "http://" + this.host + ":" + this.port + "/wd/hub/session" 
                + (this.sessionId ? ("/" + this.sessionId + "/" + path) : ""),
			"method": "POST",
			"body": body,
			"headers": {"content-type": "application/json", "cache-control": "max-age=0"}
		}
		return this.request(options)
    },

    GET: function WD_GET(path) {
        //direct GETs to the session. 
        //make sure the cache is busted so screenshots are fresh
		var options = {
			"url": path.match(/^http/) ? path : "http://" + this.host + ":" + this.port + "/wd/hub/session/" + this.sessionId + "/" + path,
			"headers": {"content-type": "application/json", "cache-control": "no-cache", "If-None-Match": "\"none shall match\""},
			"method": "GET"
		}
		return this.request(options);   
    },

    DELETE: function WD_DELETE() {
        //delete the current session
        var options = {
            "url": "http://" + this.host + ":" + this.port + "/wd/hub/session/" + this.sessionId,
            "headers": {"content-type": "application/json"},
            "method": "DELETE"
        }
        this.request(options); 
        this.sessionId = null;
        Log.Message("##############################################################");
    },


//WebDriver methods using the JsonWireProtocol https://code.google.com/p/selenium/wiki/JsonWireProtocol
//the GET and POST methods above direct the requests to the current session
    init: function WD_INIT(newSession) {
        //start a new session using the named browser or the default
        if (typeof newSession === "string") {
            this.setup.desiredCapabilities.browserName = newSession;
            this.sessionId = null;
        }
        Log.Message("***********************************************************");
        Log.Message("TEST BROWSER: " + this.setup.desiredCapabilities.browserName);
    	var sessionData = this.POST(this.setup).sessionId;
        this.sessionId = sessionData;
        Delay(5e3);
        return sessionData;
    },
    go: function WD_GO(url) {
        Log.Message(">>> " + url)
        this.POST("url", {"url": url});
    },
    screenshot: function WD_screenshot(fileName) {
        //screenshots are returned as Base64 encoded PNGs
        //so decode and save locally
        var base64String = this.GET("screenshot").value;
        var binaryData = dotNET.System.Convert.FromBase64String(base64String);
        dotNET.System_IO.File.WriteAllBytes(fileName, binaryData);
    },
    JQ: function WD_jQuery(jqselector, method, parm) {
        //execute jQuery (if present - not checked)
        //returns the value of the method call with an optional (single parameter
        return WD.POST("execute", {"script": "return $(\"" + jqselector + "\")." + method + "(" + ((arguments.length > 1) ? "\"" + parm + "\"" : "") + ")", "args": []}).value;                
    },  
    
//element methods
    $: function WD_findElement(selector, index) {
        //default to finding a list of elements based on the selector
        var elementList = this.POST("elements", this.$id(selector)).value;
        if (!elementList || !elementList.length) {
            //element not found
            return {
                Exists: false,
                visible: function notVisible() {
                    return false;
                }
            }
        }
        //if the list is a single element or index is specified, return a single element
        if ((arguments.length === 2) || (elementList.length === 1)) {
            return this.$element(elementList[index = index || 0].ELEMENT, selector, index);
        }
        return {
            //return list with a method iterator
            elementList: elementList,
            each: function WD_element_each(action, arg) {
                Log.Message("each performing multiple " + action + "s");
                return MAP(this.elementList, function WD_each_element(listItem) {
                    return WD.$element(listItem.ELEMENT, selector, index)[action](arg);
                });
            }
        }
    },
    $id: function WD_splitIdentifier(selector) {
    //use the first character of selector to determine how to find the selection
        var by = selector.slice(0,1);
        if (by.match(/(\.|#|\w)/)) {
            return {"using": "css selector", "value": selector};
        }
        if (by === "^") {
            return {"using": "link text", "value": selector.slice(1)};
        }
        if (by === "<") {
            return {"using": "tag name", "value": selector.slice(1, -1)};
        }
        if (by === "'") {
            return {"using": "xpath", "value": "//*[text()=" + selector + "]"};
        }
        if (by === "@") {
            return {"using": "xpath", "value": "//*[" + selector + "]"};
        }
        if (selector.slice(0,2) === "//") {
            return {"using": "xpath", "value": selector};
        }    
        return null;
    }, 
    //construct an element object using the found element id
    //documented in the JsonWireProtocol
    $element: function WD_elementBuilder(elementId, selector, index) {
        return {
            length: 1,
            elementId: elementId,
            selector: selector,
            index: index || 0,
            each: function WD_dummy_each(action, arg) {
            //provide a dummy each function, so API is consistent
                Log.Message("each performing a single click");
                return [this[action](arg)];
            },
            click: function WD_element_click() {
                if (WD.setup.desiredCapabilities.browserName !== "android") {
                    this.moveto();
                    WD.POST("element/" + this.elementId + "/click");    
                } else {
                    this.touchClick();
                }
                return this;
            },
            touchClick: function WD_element_touchClick() {
                return WD.POST("touch/click", {"element": this.elementId});
            },
            css: function WD_element_css(attribute) {
                return WD.GET("element/" + this.elementId + "/css/" + attribute).value;
            },
            text: function WD_element_text(cb) {
                var _text = WD.GET("element/" + this.elementId + "/text").value;
                if (cb) {
                    cb(_text);
                }
                return _text;
            },
            set: function WD_element_set(newValue) {//Send a sequence of key strokes to an element.
                WD.POST("element/" + this.elementId + "/value", 
                    {"value": newValue.split("")});//The sequence of keys to type. An array must be provided.
                return this;
            },
            css: function WD_element_css(propertyName) {//The CSS property to query should be specified using the CSS property name, not the JavaScript property name (e.g. background-color instead of backgroundColor)
                return WD.GET("element/" + this.elementId + "/css/" + propertyName).value;
            },
            attr: function WD_element_attribute(propertyName) {
                return WD.GET("element/" + this.elementId + "/attribute/" + propertyName).value;
            },
            selected: function WD_element_selected() {
                return WD.GET("element/" + this.elementId + "/selected").value;
            },
            enabled: function WD_element_enabled() {
                return WD.GET("element/" + this.elementId + "/enabled").value;
            },
            visible: function WD_element_visible() {
                return WD.GET("element/" + this.elementId + "/displayed").value;
            },
            moveto: function WD_element_moveto() {
                return WD.POST("moveto", {"element": this.elementId});
            },
            hover: function WD_element_hover() {//no support in WebDriver, so trigger hover event via jQuery
                this.JQ("trigger", "mouseenter");
                Delay(500);
                return this.JQ("trigger", "mouseenter");
            },   
            JQ: function WD_element_jQuery(method, parm) {
                var jqselector = this.selector;
                if (jqselector.slice(0,1) === "@") {
                    jqselector = "[" + jqselector.slice(1) + "]";
                }
                return WD.POST("execute", {"script": "return $(\"" + jqselector + "\")." + method + "(" + ((arguments.length > 1) ? "\"" + parm + "\"" : "") + ")", "args": []}).value;                
            },  
            $: function WD_element_findSubElement(selector, index) {
                //find sub elements starting from this element
                var subElementList = WD.POST("element/" + this.elementId + "/elements", WD.$id(selector)).value;
                if (!subElementList || !subElementList.length) {
                    return {
                        Exists: false,
                        visible: function notVisible() {
                            return false;
                        }
                    }
                }
                if ((arguments.length === 2) || (subElementList.length === 1)) {
                    index = index || 0;
                    Log.Warning(selector + ":" + index);
                    return WD.$element(subElementList[index].ELEMENT, selector, index);
                }
                
            }
        }            
    }
}

//example usage

function WD_signIn() {
    WD.go(testURL);
    //finding elements by id
    WD.$("#username").set("user@testedwebsite.com");
    WD.$("#password").set("12345");
    WD.$("#signIn").click();
},

function WD_site_create(siteParms) {
    //finding elements by AngularJS properties
    WD.$("@ng-model=\"model.newSite.name\"").set(siteParms.Name);
    WD.$("@ng-model=\"model.newSite.shortName\"").set(siteParms.ShortName);
    //finding element by class
    WD.$(".select2-container").click()
    //finding element by text content
    WD.$("'Save'").click();
},
function WD_view(viewType) {
    //finding an element by its tooltip text
    WD.$("//li[@tooltip='" + viewType + " view']/a/i").click(); 
},
function WD_appInfo() {
//converting a 2-column table to JSON
    var _appInfo = {};
    var flipper = 1;
    //iterate through all the table cells
    WD.$("<td>").each("text", function (cellValue) {
    //group the cells by left: right
        if (flipper = 1 - flipper) {
            _appInfo[lastValue] = cellValue;
        }
        lastValue = cellValue
    });
    return _appInfo;
}

