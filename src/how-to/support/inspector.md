<a id="inspector"></a>

# Debugging Wire issues using the Inspector

The inspector in your web browser can be a very handy tool, when debugging issues people see in their web browsers.

## Pulling a Calls Config / SFT errors

Customer complaint: some conference calling not working, end user cannot get or has not yet gotten logs to us.

This procedure should get us:

* The calls configuration of the backend.
* The HTTP error code that SFT MAY be presenting.

Procedure:

From one of the affected webapp users' machine:

* Right click, anywhere in the web application, and open the inspector.
* The browser should now have a new window in it. This is the browser's inspector showing you the code for whatever you clicked on.
    * Select the 'Network' tab of the inspector, and return to wire without closing the inspector window.
* In the wire application, select a room where others have successfully been placing conference calls, and where there are NO federated users.
    * Place a call. You should see files loading into the 'Network' tab of the inspector. The results of placing this call do not matter, but do let the call either succeed (and hang it up!), or fail.
* In the inspector, Click on the 'File' or 'Name' column header once. This should sort the requests that were sent.
    * If there is not a 'Method' column shown, please right click on 'Name' or 'File', and select 'Method' to make it visible.
* Look for a file named either 'v2', or 'v2?limit=3'. that is the settings given to you by your wire backend, for calling.
    * There will be at least two shown. In the 'method' column, the files will have a method of 'GET', 'GET + Preflight', or 'OPTIONS'. Click on the one labeled either 'GET'.
* A new pane will have popped open with 'Headers', 'Response', 'Timings', and other tabs.
    * Click on the 'Response' tab.
 
You should now see the 'calls config'.

Your calls config is a JSON document, made of several sections, telling clients what credentials to use, and where they should find the calling servers.

* Please stay in the inspector, save a copy of the calls config, and give a copy to your support team.

* Examine the calls configuration for the 'sft_servers' section (not 'sft_servers_all').
    * There should be a single URL in there, pointing to https://<YOUR_SFT_SERVER_HERE>/
    * There should also be entries for each TURN server in your environment.

* Your inspector should still have the 'Network' tab open.
    * Close the portion of the inspector that shows our request. This is the part that has 'Headers', 'Response', and 'Timings' tabs.
* You should now see the list of requests and responses again.
    * If there is not a 'Url' column shown, please right click on 'Name', or 'File', and select 'Url' to make it visible.
* Click on the 'Url' column header once. This should sort the requests that were sent by Url.
* Find the requests that have the same URL as you found in the 'sft_servers' section of the calls config.
* Screenshot them. ensure that the 'Name' or 'File' is readable, the 'Url' is fully visible, the 'Method' is visible, and the 'Status' is visible.

## Examining file upload/download problems

Customer Complaint:

File upload/download is not working. someone uploaded a file, but i can’t download it. I can try to send things, but they never upload. I’m on webapp.
Procedure:

From one of the affected webapp users' machine:

* Right click, anywhere in the web application, and open the inspector.
    * The browser should now have a new window in it. This is the browser's inspector showing you the code for whatever you clicked on.
* Select the 'Network' tab of the inspector, and return to wire without closing the inspector window.
* In the wire application, select a room where others have successfully been uploading files, and where there are NO federated users.
    * Attempt to download a file by clicking on the three dots next to the file, and selecting ‘Download’. You should see traffic in the 'Network' tab of the inspector. The results of your attempt do not matter.
* In the inspector, Click on the 'File' or 'Name' column header once. This should sort the requests that were sent.
    * If there is not a 'Method' column shown, please right click on 'Name' or 'File', and select 'Method' to make it visible.
* Look for a file who’s name starts with “3-4”
    * There will be at least two shown. In the 'method' column, the files will have a method of 'GET + Preflight', or 'OPTIONS'.
    * after the two "3-4" files shown, there will be a 'GET' request for the same filename, minus the '3-4-' on the beginning. It will be a GET request.
* Screenshot the three files. Ensure that the 'Name' or 'File' is readable, the 'Url' is fully visible, the 'Method' is visible, and the 'Status' is visible.
