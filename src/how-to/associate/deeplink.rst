Using a Deep Link to connect an App to a Custom Backend
=======================

Introduction
------------

Once you have wire-server set up and configured, you may want to use a client other than the web interface. There are a few ways to accomplish this:
- Using a Deep Link
- Registering the backend with Wire for re-direction.

Assumptions:
- You have wire-server installed and working
- You have a familiarity with JSON files
- You can place a JSON file on an HTTPS supporting web server somewhere your users can reach.

In order to connect to a custom backend:

Connecting to a custom backend utilizing a Deep Link
------------

A deep link is a special link a user can click on after installing wire, but before setting it up. This link instructs their wire client to connect to your wire-server, rather than wire.com.

From a user's perspective:
------------

- First, a user installs the app from the store
- The user clicks on a deep link, which is formatted similar to: `wire://access/?config=eu-north2.mycustomdomain.de/configs/backend1.json`
- The app will ask the user to confirm that they want to connect to a custom backend. If the user cancels, the app exits.
- Assuming the user did not cancel, the app will download the file `eu-north2.mycustomdomain.de/configs/backend1.json` via HTTPS. If it can't download the file or the file doesn't match the expected structure, the wire client will display an error message (Invalid link).
- The app will memorize the various hosts (REST, websocket, team settings, website, support) specified in the JSON and use those when talking to your backend. 
- In the welcome page of the app, a "pill" (header) is shown at the top, to remind the user that they are now on a custom backend. A button "Show more" shows the URL of where the configuration was fetched from.

From your perspective:
------------

You need to create a .json file, and host it somewhere users can get to. This .json file needs to specify the URLs of your backend. For the production wire server that we host, the json file would look like::

  {
      "endpoints" : {
          "backendURL" : "https://prod-nginz-https.wire.com",
          "backendWSURL" : "https://prod-nginz-ssl.wire.com",
          "blackListURL" : "https://clientblacklist.wire.com/prod",
          "teamsURL" : "https://teams.wire.com",
          "accountsURL" : "https://accounts.wire.com",
          "websiteURL" : "https://wire.com"
      },
      "title" : "Production"
  }

There is no requirement for these hosts to be consistent, e.g. the REST endpoint could be `wireapp.pineapple.com` and the team setting `teams.banana.com`.

You now need to get a link to that file to your users, prepended with 'wire://access?config='. For example, you can save the above .json file as 'wire.json', and use 


## Option 2: Using a registered domain

If the custom backend has been associated with a domain on the Wire cloud, then there is another [simpler flow](005-custom-backend-by-domain.md)
