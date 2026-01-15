<a id="inspector"></a>

# Examining Wire issues using the Web Inspector

The Web Inspector in your web browser can be a very handy tool, when debugging issues people can see in their web browsers.

## Conference Calling

### Pulling a Calls Config

End User complaint: Some conference calling not working, end user cannot get logs.

#### What are we gathering
This procedure should get us:

* The calls configuration of the backend.
* The HTTP error code that SFT may be presenting.

Procedure:

From one of the affected webapp users' machine:

* Right click, anywhere in the web application, and open the inspector.
* The browser should now have a new window in it. This is the browser's inspector showing you the code for whatever you clicked on.
    * Select the 'Network' tab of the inspector, and return to Wire without closing the inspector window.
* In the Wire application, select a channel/group where others have successfully been placing conference calls, and where there are NO federated users.
    * Place a call. You should see files loading into the 'Network' tab of the inspector. The results of placing this call do not matter, but do let the call either succeed (and hang it up!), or fail.
* In the inspector, Click on the 'File' or 'Name' column header once. This should sort the requests that were sent.
    * If there is not a 'Method' column shown, please right click on 'Name' or 'File', and select 'Method' to make it visible.
* Look for a file named either 'v2', or 'v2?limit=3'. that is the settings given to you by your Wire backend, for calling.
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

## File Sharing

### Examining file Upload/Download Problems

End User Complaint:

File upload/download is not working. someone uploaded a file, but i can’t download it. I can try to send things, but they never upload. I’m on webapp.
Procedure:

#### What are we gathering:

 * The HTTP error codes that your S3 service may be presenting.

#### Process:
From one of the affected webapp users' machine:

* Right click, anywhere in the web application, and open the inspector.
    * The browser should now have a new window in it. This is the browser's inspector showing you the code for whatever you clicked on.
* Select the 'Network' tab of the inspector, and return to Wire without closing the inspector window.
* In the Wire application, select a channel/group where others have successfully been uploading files, and where there are NO federated users.
    * Attempt to download a file by clicking on the three dots next to the file, and selecting ‘Download’. You should see traffic in the 'Network' tab of the inspector. The results of your attempt do not matter.
* In the inspector, Click on the 'File' or 'Name' column header once. This should sort the requests that were sent.
    * If there is not a 'Method' column shown, please right click on 'Name' or 'File', and select 'Method' to make it visible.
* Look for a file who’s name starts with “3-4”
    * There will be at least two shown. In the 'method' column, the files will have a method of 'GET + Preflight', or 'OPTIONS'.
    * after the two "3-4" files shown, there will be a 'GET' request for the same filename, minus the '3-4-' on the beginning. It will be a GET request.
* Screenshot the three files. Ensure that the 'Name' or 'File' is readable, the 'Url' is fully visible, the 'Method' is visible, and the 'Status' is visible.

## Team Management

### Examining CORS Problems

End User Complaint:

The 'Enterprise Provisioning' tab of my team settings doesn't show anything, and is constantly loading.

#### What are we gathering
This procedure should get us:

* Javascript console errors (If applicable)
* HAR file of the session (Likely containing credentials, treat carefully!)
* Evidence that CORS is failing for one backend URL
    * Curl request, and response
	* screen shots of the network tab, for a failing request, including headers.
* Evidence that CORS succeeds for another extremely related URL
    * Curl request, and response
	* screen shots of the network tab, for a successful request, including headers.


#### Process:
From one of the affected Team Management users' machine:

* Open the Team Management application.
* Right click, anywhere in the web application, and open the inspector (Inspect(Q), in firefox, Inspect in Chrome).
    * The browser should now have a new window in it. This is the browser's inspector showing you the code for whatever you clicked on.
* Select the 'Console' tab of the inspector.
    * Hit the trashcan icon in the upper left of the inspector window, to clear historic inspector errors.
* Select the 'Network' tab of the inspector.

First, we're going to gather a 'Successful' request to your backend.

* In the Team Management application, click on either 'Invitations' or 'Overview' in the right hand side.
* Your inspector should now show at least two requests in the 'Network' tab.
* In the inspector, Click on the 'File' or 'Name' column header once. This should sort the requests that were sent.
    * If there is not a 'Method' column shown, please right click on 'Name' or 'File', and select 'Method' to make it visible.
* You should see a 'GET' request to a file 'invitations?size=100', and may see an 'OPTIONS' request to the same file. click on the GET request.
* A new pane will have popped open with 'Headers', 'Response', 'Timings', and other tabs. By Default, It should have the 'Headers' tab selected.
    * Gather a screenshot of the request you selected, making sure the headers are readable. If needed, take separate shots of the request, and it's headers.

We are now going to prepare to construct an equivalent CURL request for this request. This is so that WE can verify our process works.

* Open a command line, on a linux machine that can reach the wire environment.
* Construct a curl command significantly similar to the GET request we are examiming:
    * curl <request URL> <-- our target, you will need quotes around the request URL.
    * -v <-- verbose mode, so we can see the resulting headers
    * -o good_request <-- our file to store the result of the request in.
  * -X GET <-- our method
  * -H "Origin: https://teams.wire.com"  <-- Replace teams.wire.com with the name of YOUR teams page.
  * -H <first header>
  * -H <second header>...

* Copy all of the headers from the GET request in your inspector on to the end of your curl command (placing quotes around each, and ensuring they are formatted "key: value"), then hit enter to run the request in curl. (**HINT:** Some web browsers have a 'Raw' slider, that shows them in a easier to cut and paste form!)

Copy the entire output of this terminal session for Wire. What we'll be looking for is a header in the 'response' portion (the part starting with '<' characters.) named 'access-control-allow-origin'.

* Now go to where the End User has stated content is broken.
* Select one of the GET requests, and perform the same procedure:

* Open a command line, on a linux machine that can reach the wire environment.
    * Construct a Curl command significantly similar to the GET request we are examiming:
        * curl <broken request URL> <-- our target, you will need quotes around the request URL.
        * -v <-- verbose mode, so we can see the resulting headers
        * -o bad_request <-- our file to store the result of the request in.
        * -X GET <-- our method
        * -H "Origin: https://teams.wire.com" <-- Replace teams.wire.com with the name of your teams page.
		* -H <first header>
		* -H <second header>...
    * Copy all of the headers from the GET request in your inspector, into your Curl command, then hit enter to run the request in Curl.

* Copy the entire output of your curl session for Wire, including the curl command you issued. What we'll be looking for is the absence of a header in the 'response' portion (the part starting with '<' characters.) named 'access-control-allow-origin'.

* Return to your browser
    * Gather a screenshot of the request you selected, making sure the headers are readable. If needed, take separate shots of the request, and it's headers.
	* Gather an HAR file from your network tab of your inspector (download icon for chrome, right click on a request and "Save All as HAR"). Note that HAR files are sensitive. Hand this to no-one you do not trust with your password for 15 minutes, to allow your authentication credentials in the HAR file to expire.

* Select the console tab in your inspector, and copy any content you see there, for wire.
    * right click anywhere, and save as (which saves all, not just the one you clicked on).
