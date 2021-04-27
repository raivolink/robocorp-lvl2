*** Settings ***
Documentation     Orders robots from RobotSpareBin Industries Inc.
...               Saves the order HTML receipt as a PDF file.
...               Saves the screenshot of the ordered robot.
...               Embeds the screenshot of the robot to the PDF receipt.
...               Creates ZIP archive of the receipts and the images
Library           RPA.Browser.Selenium
Library           RPA.HTTP
Library           RPA.Tables    
Library           RPA.PDF
Library           RPA.Archive
Library           RPA.Dialogs
Library           RPA.Robocloud.Secrets
Library           RPA.RobotLogListener
Suite Teardown    Close All Browsers


*** Variables ***
${ORDERS_FILE}      https://robotsparebinindustries.com/orders.csv
${PDF_FOLDER}       ${OUTPUTDIR}${/}pdf

*** Keywords ***
Open the robot order
    [Arguments]     ${url}
    Open Available Browser      ${url}    maximized=True

*** Keywords ***
Get Orders
    Download        ${ORDERS_FILE}          overwrite=True
    ${orders}=      Read Table From Csv     orders.csv
    [Return]        ${orders} 

*** Keywords ***
Close modal
    Click Button When Visible    //button[@class='btn btn-warning']

# +
*** Keywords***
Fill Order Form
    [Arguments]     ${order}
    Select From List By Index   head                                            ${order}[Head]
    Select Radio Button         body                                            ${order}[Body]
    Input Text    //input[@placeholder='Enter the part number for the legs']    ${order}[Legs]
    Input Text                  address                                         ${order}[Address]
    
    
# -

*** Keywords ***
Preview Robot
    Click Button When Visible        preview
    Wait Until Element Is Visible    robot-preview-image

*** Keywords***
Order Robot
    Click Button When Visible        order
    Wait Until Element Is Visible    receipt

*** Keywords ***
Save Order Receipt as PDF
    [Arguments]     ${order_number}=0
    ${html_content_as_string}=  Get Element Attribute    receipt    outerHTML
    ${filepath}     Set Variable    ${PDF_FOLDER}${/}${order_number}.pdf
    HTML to PDF     ${html_content_as_string}  ${filepath}
    [Return]        ${filepath}


*** Keywords ***
Take a screenshot of the robot
    [Arguments]     ${order_number}=0
    Wait Until Element Is Visible    robot-preview-image
    Sleep    50ms
    ${screenshot_path}=     Capture Element Screenshot     robot-preview-image  ${OUTPUTDIR}${/}screens${/}${order_number}.png
    Log To Console  ${screenshot_path}
    [Return]           ${screenshot_path}

*** Keywords ***
Embed the robot screenshot to the receipt PDF file
    [Arguments]     ${screenshot}       ${pdf}
    Add Watermark Image To PDF
    ...             image_path=${screenshot}
    ...             source_path=${pdf}
    ...             output_path=${pdf}

*** Keywords***
Order Another Robot
    Click Button When Visible    order-another

*** Keywords ***
Create ZIP package from PDF files
    ${zip_file_name}=    Set Variable    ${OUTPUTDIR}${/}PDFs.zip
    Archive Folder With Zip
    ...    ${PDF_FOLDER}
    ...    ${zip_file_name}

*** Keywords ***
Collect Order File From User
    Create Form    Provide url to orders file
    Add Text Input    Url    url
    &{response}=    Request Response
    [Return]    ${response["url"]}

*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    ${secret}=    Get Secret    urlsecret
    ${file_loc}=    Collect Order File From User
    IF    '${file_loc}' == 'None'
        ${file_loc}     Set Variable   ${secret}[url]
        Log     ${file_loc}
        Open the robot order    ${file_loc}
    ELSE
        Open the robot order    ${file_loc}
    END
    ${orders}=  Get Orders
    FOR    ${order}    IN    @{orders}
        Close modal
        Fill Order Form     ${order}
        Mute Run On Failure      Wait Until Keyword Succeeds
        ${orig timeout} =	Set Selenium Timeout	1 seconds
        Wait Until Keyword Succeeds     5x      200ms      Preview Robot
        Wait Until Keyword Succeeds     5x      200ms      Order Robot
        Set Selenium Timeout	${orig timeout}
        ${pdf}=     Save Order Receipt as PDF   ${order}[Order number]
        ${screenshot_path}=    Take a screenshot of the robot   ${order}[Order number]
        Embed the robot screenshot to the receipt PDF file  ${screenshot_path}  ${pdf}
        Order Another Robot
    END    
    Create ZIP package from PDF files


