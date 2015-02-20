# Haka Innovation Data Transfer Tool

<a href="https://githubsfdeploy.herokuapp.com?owner=brosiusad&repo=Haka-Innovation-Data-Transfer-Tool">
  <img alt="Deploy to Salesforce"
       src="https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/src/main/webapp/resources/img/deploy.png">
</a>

This is a tool that makes use of the [apex-sobjectdataloader](https://github.com/afawcett/apex-sobjectdataloader) project from [Andrew Fawcett](https://github.com/afawcett) to export and import data from/into a Salesforce instance in which has been installed the Haka "Innovation" app from [Haka Products](http://hakaproducts.com).  

## Usage

#### Exporting Data
1. Login to the source org.
2. Run this code as an anonymous block from the Developer Console

    ```apex
    HakaInnovationDataTransferTool tool = new HakaInnovationDataTransferTool();
    String jsonResult = tool.export();
    System.debug(jsonResult);
    ```

3. Open the debug log and find the DEBUG message from line 3 above
4. Copy the JSON (stripping the bit at the beginning from the SF log) and save it in a text file.

#### Importing Data
1. Host the JSON file on a publicly-accessible web server (you can host it on your local machine and use ngrok or similar to open a secure connection to your local machine)
2. Login to the destination org
3. Create a Remote Site Setting for the web server
4. Run this code as an anonymous block from the Developer Console

```apex
HakaInnovationDataTransferTool tool = new HakaInnovationDataTransferTool();
tool.import('server_url', 'json_filename);
``` 