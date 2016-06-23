# RileyLink iOS App

[![Join the chat at https://gitter.im/ps2/rileylink](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/ps2/rileylink?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge) [![Build Status](https://travis-ci.org/ps2/rileylink_ios.svg?branch=master)](https://travis-ci.org/ps2/rileylink_ios)

The RileyLink iOS app connects to a RileyLink device via Bluetooth Low Energy (BLE, or Bluetooth Smart) and uploads CGM and pump data to a Nightscout instance via the REST API. The Nightscout web page is also displayed in the App.

### Configuration

* Pump ID - Enter in your six digit pump ID
* Nightscout URL - Should look like `http://mysite.azurewebsites.net`. You can use http or https.  Trailing slash or no trailing slash.
* Nightscout API Secret - Use the unhashed form, exactly specified in your `API_SECRET` variable.
