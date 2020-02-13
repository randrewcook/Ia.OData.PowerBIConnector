// This file contains your Data Connector logic
[Version = "1.0.0"]
section Ia.OData.PowerBIConnector;

//Global Variables
odata_uri = "https://services.itrontotal.com/odata";
client_id = "3c8cc97b-f73c-7a31-d5b1-ac35f948bebc";
redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
token_uri = "https://idenserver.itrontotal.com/connect/token";
authorize_uri = "https://idenserver.itrontotal.com/connect/authorize";
logout_uri = "https://idenserver.itrontotal.com/connect/endsession";
scopes = "tslug openid profile roles email offline_access tid.";
grantType = "client_credentials";
TenantFile = Json.Document(Extension.Contents("IATenants.json"));

//Tenant = Value.ReplaceType(GetTenantName,GetTenantType);

Tenant = GetTenantName("TEMPE");

GetTenantType = type function (
        TenantSel as (
            type text meta [
                Documentation.FieldCaption = "Tenant",
                Documentation.FieldDescription = "Enter Tenant Short Name",
                Documentation.SampleValues = {"LVVWD", "SUNRI"}
        ]))
        as any;

//Get the tenant from the user
GetTenantName = (TenantSel as text) as text =>
    let
       Result=TenantSel
    in 
       Result;

tenantid = GetTenantId(Tenant);

GetTenantId = (tenantSelected as text) =>
let
    Gettid = List.Select(TenantFile, each [Tenant]=tenantSelected),
    tidRecord = Gettid{0},
    result = Record.Field(tidRecord,"tid")
in
    result;

//Main
[DataSource.Kind="Ia.OData.PowerBIConnector", Publish="Ia.OData.PowerBIConnector.Publish"]
shared Ia.OData.PowerBIConnector.Feed = () =>
    let
        source = OData.Feed(odata_uri, [#"itron-route-override" = "iaodata"], [ ODataVersion = 4, MoreColumns = true ])
    in
        source;

// Data Source Kind description
Ia.OData.PowerBIConnector = [
    TestConnection = (dataSourcPath) => { "Ia.OData.PowerBIConnector.Feed" },
    Authentication = [
        OAuth = [
            StartLogin = StartLogin,
            FinishLogin = FinishLogin,
            Refresh = Refresh,
            Logout = Logout
        ]
    ],
    //SupportsEncryption = true,
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
Ia.OData.PowerBIConnector.Publish = [
    Beta = true,
    Category = "Other",
    SupportsDirectQuery = true,
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://access.itron.com/support/ItronAnalytics",
    SourceImage = Ia.OData.PowerBIConnector.Icons,
    SourceTypeImage = Ia.OData.PowerBIConnector.Icons
];

Ia.OData.PowerBIConnector.Icons = [
    Icon16 = { Extension.Contents("Itron16.png"), Extension.Contents("Itron20.png"), Extension.Contents("Itron24.png"), Extension.Contents("Itron32.png") },
    Icon32 = { Extension.Contents("Itron32.png"), Extension.Contents("Itron40.png"), Extension.Contents("Itron48.png"), Extension.Contents("Itron64.png") }
];


//OAuth Flow Management Functions
StartLogin = (resourceUrl, state, display) =>
    let
        authorizeUrl = authorize_uri & "?" & Uri.BuildQueryString([
            client_id = client_id,  
            redirect_uri = redirect_uri,
            scope = scopes & tenantid,
            response_type = "code"   
        ])
    in
        [
            LoginUri = authorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = 720,
            WindowWidth = 1024,
            Context = null
        ];

FinishLogin = (context, callbackUri, state) =>
    let
        parts = Uri.Parts(callbackUri)[Query],
        result = if (Record.HasFields(parts, {"error", "error_description"})) then 
                    error Error.Record(parts[error], parts[error_description], parts)
                 else
                    TokenMethod("authorization_code", "code", parts[code])
    in
        result;

Refresh = (resourceUrl, refresh_token) => TokenMethod("refresh_token", "refresh_token", refresh_token);

Logout = (token) => logout_uri;

TokenMethod = (grantType, tokenField, code) =>
    let
        queryString = [
            client_id = client_id,
            scope = scopes & tenantid,
            grant_type = grantType,
            redirect_uri = redirect_uri
        ],
        queryWithCode = Record.AddField(queryString, tokenField, code),

        tokenResponse = Web.Contents(token_uri, [
            Content = Text.ToBinary(Uri.BuildQueryString(queryWithCode)),
            Headers = [
                #"Content-type" = "application/x-www-form-urlencoded",
                #"Accept" = "application/json"
            ],
            ManualStatusHandling = {400} 
        ]),
        body = Json.Document(tokenResponse),
        result = if (Record.HasFields(body, {"error", "error_description"})) then 
                    error Error.Record(body[error], body[error_description], body)
                 else
                    body
    in
        result;

// 
// Load common library functions
// 
// TEMPORARY WORKAROUND until we're able to reference other M modules
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

// Diagnostics module contains multiple functions. We can take the ones we need.
Diagnostics = Extension.LoadFunction("Diagnostics.pqm");
Diagnostics.LogValue = Diagnostics[LogValue];
Diagnostics.LogFailure = Diagnostics[LogFailure];