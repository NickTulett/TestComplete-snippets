//USEUNIT JSON (crockford's json2.js) if using TestComplete <11

var winscp = {
    //download winscp and run the .exe to create a session
    session: "<your session name>",
    //but note we use the .com
    exe: "C:\\...\\winscp.com",
    shell: Sys.OleObject("WScript.Shell"),
    console: null, 
    topheads: {},//store results of (multiple) calls to tophead()
    dfs: {},//store results of (multiple) calls to df()
    
    stdin: function winscp_stdin(cmd) {
        this.console.StdIn.Write(cmd + "\n");
        return this;
    },
    stdout: function winscp_stdout(cb) {
        var lines = this.console.StdOut.ReadAll().split("\n");
        if (cb) {
            MAP(lines, cb);
        } else {
            return lines;
        }
    },
    exit: function winscp_exit() {
        this.stdin("exit");
        return this;
    },
    exec: function winscp_exec(cmd) {
        this.console = this.shell.Exec(this.exe + " " + this.session + " /command \"call " + cmd + "\"");
        this.exit();
        return this;
    },
    
    table: function winscp_table(obj, firstItemOfInterest) {
        //convert tabular cli results to a JSON object
        //and add to the corresponding result store
        var lines = this.stdout();
        //look for the line that contains the first item of interest
        for (var l = lines.length; l--;) {
            if (~lines[l].indexOf(firstItemOfInterest)) {
                break;
            }
        }
        //use the column names for the result object keys
        var cols = lines[l].replace(/(^\s*|\s*$)/g, "").replace(/\s+/g, " ").split(" ");
        //identify each instance by the current timestamp
        var time = (new Date()).toTimeString();
        var line;
        this[obj][time] = [];
        l++;
        while ((line = lines[l++])) {
            line = line.replace(/(^\s*|\s*$)/g, "").replace(/\s+/g, " ").split(" ");
            var item = {};
            for (var j = 0, cl = cols.length; j < cl; j++) {
                item[cols[j]] = line[j];
            }
            this[obj][time].push(item);
        }
        return this;        
    },
    
    tophead: function winscp_tophead(lineCount) {
        lineCount = lineCount || 12;
        this.exec("top -c -b | head -n " + lineCount);
        this.table("topheads", "PID");
        return this;
    },
    df: function winscp_df() {
        this.exec("df");
        this.table("dfs", "Filesystem");
        return this;
    },
    lsr: function winscp_lsr(directory) {
        //recursive ls of a directory
        if (directory.slice(-1) !== "/") {
            directory += "/";
        } 
        this.exec("ls -lhR " + directory);
        //copy directory structure and file details to a JSON object
        this.lsrs = {};
        var folder;
        var columns = ["permissions", "number of hard links", "owner", "group", "size", "month", "day", "time", "name"];
        this.stdout(function (line) {
            if (~line.indexOf("/")) {
                folder = line;
                winscp.lsrs[folder] = {};
                winscp.lsrs[folder]["files"] = [];
                return;
            }
            if (~line.indexOf("total ")) {
                winscp.lsrs[folder]["total"] = line.split(" ")[1];
                return;
            }
            if (~line.indexOf("winscp>")) {
                return;
            }
            if (line.length > 1) {
                var fileDetails = line.replace(/\s{1,4}/g, " ").replace(/\s$/, "").split(" "),
                    fileDetail = {};
                for (var f = 0, l = fileDetails.length; f < l; f++) {
                    fileDetail[columns[f]] = fileDetails[f];
                }
                winscp.lsrs[folder]["files"].push(fileDetail);
            }                                                        
        });
        return this;
    },
    replaceLine: function winscp_replaceLine(lineNumber, newLine, fileLocation) {
        this.exec("sed -i '" + lineNumber + "s/.*/" + newLine + "/' " + fileLocation);
        return this; 
    },
    catLog: function winscp_catLog(fileLocation) {
        this.exec("cat " + fileLocation)
            .stdout(function (line) {Log.Message(line);});
        return this;
    }
};

function winSCP_test() {
    winscp
        .tophead()
        .df()
        .tophead(10)
        .df()
        .lsr("testResults");
    Log.Message(JSON.stringify(winscp.topheads));
    Log.Message(JSON.stringify(winscp.dfs));
    Log.Message(JSON.stringify(winscp.lsrs));
}
