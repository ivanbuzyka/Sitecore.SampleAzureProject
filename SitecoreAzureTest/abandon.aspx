<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="abandon.aspx.cs" Inherits="SitecoreAzureTest.abandon" %>
<script runat="server">
  
  void Page_Load(object sender, System.EventArgs e) {
        Session.Abandon();
  }
  
</script>  
<!DOCTYPE html>

<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title></title>
</head>
<body>
    <form id="form1" runat="server">
    <div>
        <span>Abandoned!</span>
    </div>
    </form>
</body>
</html>
