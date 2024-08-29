#!/bin/bash
#############################################
##### Common function
#############################################
### print msg to file
DOECHO(){
echo -e "$1" >> "chk.out"
}

### get sugar location input
rm "chk.out"
DOECHO "SugarCRM root: $1"
if [ $# -lt 2 ];
   then
     echo "* Please input SugarCRM location and user email address."
     echo "  ex)./123.sh /var/www/htdocs/sales/salesconnect useremail@us.ibm.com"
     echo ""
     echo "* You may set extra params to run multiple IEB connectivity testing."
     echo "* For example to run testing every 10 minutes, till 100 counts,"
     echo "  ex)./123.sh /var/www/htdocs/sales/salesconnect useremail@us.ibm.com 100 600"

     exit
else
 out=$(ls $1)
   if [ "$out" = "" ];
   then
      echo "invalid location";
      exit
   fi
fi

sugar=$1
uemail=$2
cver=$(curl --version)
DOECHO "$cver"

#set -x verbose

### display function description
FUNCDESC(){
DOECHO $'\n'
DOECHO "***************************************************************************"
DOECHO "*"
DOECHO "* $1"
DOECHO "*"
DOECHO "***************************************************************************"
}

SUBFUNCDESC(){
DOECHO $'\n'
DOECHO "***************************************************************************"
DOECHO "* $1"
DOECHO "***************************************************************************"
}

### parse string and show permission in case
SHOWPARSE(){
val=$1
val=${val//\'/}
val=${val//;/}
val=${val//[[:space:]]/}
DOECHO "setting in config_override.php: "$val
case "$2" in
 "sk")
   sk=$val
   DOECHO $(ls -l $val)
   ;;
 "sc")
   sc=$val
   DOECHO $(ls -l $val)
   ;;
 "dc")
   dc=$val
   DOECHO $(ls -l $val)
   ;;
 "cp")
   cp=$val
   ;;
 "lu")
   lu=$val
   ;;
 "lc")
   lc=$val
   ;;
 "cu")
   cu=$val
   ;;
 "fcn")
   fcn=$val
   DOECHO "functional id cnum: "$val
   ;;
 "femail")
   femail=$val
   DOECHO "functional id: "$val
   ;;
 "ispsc")
   ispsc=$val
   ;;
 "ispdojoc")
   ispdojoc=$val
   ;;
 "ispu")
   ispu=$val
   DOECHO "ispserver: "$val
   ;;
esac
}

### show value and warning in case
SHOWVALUE(){
case "$2" in
 "")
 DOECHO "$1: !!!!!!!!empty!!!!!!!!!!"  
;;
 *) DOECHO "$1 :$2";;
esac
}

### show curl response status
SHOWSTATUS(){
echo "$1" >out.tmp
status="$(grep "HTTP/1.1" out.tmp)"
rm out.tmp
case "$status" in
 *200*)
 echo -e "   * status: "$status
;;
 *201*)
 echo -e "   * status: "$status
;;
 "")
 echo -e "   * error:please refer to chk.out."
;;
 *) echo -e "   * status: "$status
;;
esac
}

### show curl response cookie
SHOWCOOKIE(){
res=${1#*Set-Cookie: }
lcookie="Cookie: ${res%; Path=*}"
echo -e "   * "$lcookie
}

### get created community location 
GETLOC(){
echo "$1" >out.tmp
commloc="$(grep "Location: " out.tmp)"
commloc="${commloc#*Location: }"
rm out.tmp

echo "   * Location: ""$commloc"
commurl="/communities""${commloc#*/communities}"
commurl=$(echo "$commurl"  | tr -d '[\n]')
commurl=$(echo "$commurl"  | tr -d "\r")

echo "   * community created: ""$commurl"
commid="${commurl#*communityUuid=}"

echo "   * community id :$commid"
DOECHO "community id :$commid"
}

### get userid from profile
GETUID(){
echo "$1" >out.tmp
userid="$(grep "<snx:userid>" out.tmp)"
rm out.tmp

userid=${userid#*<snx:userid>}
userid=${userid%</snx:userid>*}
echo -e "   * snx:userid="$userid
case "$2" in
 "fuid")
   fuid=$userid
   ;;
 "uuid")
   uuid=$userid
   ;;

esac
}

#############################################
##### read setting from config_override.php
#############################################
INIT(){
desc="- read settings from config_override.php in "$sugar
FUNCDESC "$desc"
echo -e "$desc"

lu=$(grep "'ieb_lpde_base_url'" $sugar"/"config_override.php)
lc=$(grep "'ieb_lpde_cookie'" $sugar"/"config_override.php)
cu=$(grep "'ieb_connections_base_url'" $sugar"/"config_override.php)
sk=$(grep "'sugar_key'" $sugar"/"config_override.php)
sc=$(grep "'sugar_cert'" $sugar"/"config_override.php)
dc=$(grep "'datapower_cert'" $sugar"/"config_override.php)
cp=$(grep "'ca_path'" $sugar"/"config_override.php)
femail=$(grep "'functional_id'" $sugar"/"config_override.php)
fcn=$(grep -E "functional_ids_to_install.*0.*employee_cnum"  $sugar"/"config_override.php)
ispsc=$(grep "'ibm_widget_proxiedHost'" $sugar"/"config_override.php)
ispdojoc=$(grep "'ibm_widget_dojoJSAbsolutePath'" $sugar"/"config_override.php)
# 25909 - add checking site_url
issiteurl=$(grep "'site_url'" $sugar"/"config_override.php)
SHOWVALUE "ieb_lpde_base_url" "$lu"
SHOWVALUE "ieb_lpde_cookie" "$lc"
SHOWVALUE "ieb_connections_base_url" "$cu"
SHOWVALUE "sugar_key" "$sk"
SHOWVALUE "sugar_cert" "$sc"
SHOWVALUE "datapower_cert" "$dc"
SHOWVALUE "ca_path" "$cp"
SHOWVALUE "functional_id" "$femail"
SHOWVALUE "employee_cnum" "$fcn"
SHOWVALUE "ibm_widget_proxiedHost" "$ispsc"
SHOWVALUE "ibm_widget_dojoJSAbsolutePath" "$ispdojoc"
# 25909 - add checking site_url
SHOWVALUE "site_url" "$issiteurl"
DOECHO $'\n'"** parsing information from setting"
IFS="="; Array=($lu)
SHOWPARSE ${Array[1]} "lu"

IFS="="; Array=($lc)
SHOWPARSE ${Array[1]} "lc"

IFS="="; Array=($cu)
SHOWPARSE ${Array[1]} "cu"

IFS="="; Array=($femail)
SHOWPARSE ${Array[1]} "femail"

IFS="="; Array=($fcn)
SHOWPARSE ${Array[1]} "fcn"

IFS="="; Array=($ispsc)
SHOWPARSE ${Array[1]} "ispsc"

IFS="="; Array=($ispdojoc)
SHOWPARSE ${Array[1]} "ispdojoc"

}

#############################################
##### permission check for sugar_key
#############################################
CHKSKEY(){
desc="- permission check for sugar_key"
FUNCDESC "$desc"
#echo "$desc"
IFS="="; Array=($sk)
SHOWPARSE ${Array[1]} "sk"
echo  -e "$desc"" : ""$sk"
}

#############################################
##### permission check for sugar_cert
#############################################
CHKSCERT(){
desc="- permission check for sugar_cert"
FUNCDESC "$desc"
#echo "$desc"
IFS="="; Array=($sc)
SHOWPARSE ${Array[1]} "sc"
echo -e "$desc"" : ""$sc"

}

#############################################
##### permission check for datapower_cert
#############################################
CHKDCERT(){
desc="- permission check for datapower_cert"
FUNCDESC "$desc"
#echo "$desc"
IFS="="; Array=($dc)
SHOWPARSE ${Array[1]} "dc"
echo -e "$desc"" : ""$dc"

}

#############################################
##### permission check for ca_path
#############################################
CHKCAPATH(){
desc="- permission check for ca_path"
FUNCDESC "$desc"
#echo "$desc"
IFS="="; Array=($cp)
SHOWPARSE ${Array[1]} "cp"
DOECHO $(ls -l $cp'/'GeoTrust*)
echo -e "$desc"" : ""$cp"
pos=${dc/ebs01.raleigh.ibm.com.pem*/}

echo $pos
if [ "$dc" = "$pos" ];
   then
   DOECHO "non sandbox gateway"
   DOECHO $(cat $cp'/'GeoTrust*.pem > ieb_bundle.crt)

else
   DOECHO "using sandbox gateway on ebs01"
   DOECHO $(cat $cp'/'GeoTrust*.pem $cp'/'ebs01.raleigh.ibm.com.pem > ieb_bundle.crt)

fi
#echo $(cat ieb_bundle.crt)
}

##################################################################
##### permission check for batch, common, CommonLogger.php, Log.php
##################################################################
CHKLOGPKG(){
desc="- permission check for batch, common, CommonLogger.php, Log.php"
FUNCDESC "$desc"
#echo "$desc"
DOECHO "** checking permission for batch dir"
DOECHO $(ls -l $sugar|grep "batch")
DOECHO "** checking permission for batch/common dir"
DOECHO $(ls -l $sugar'/batch'|grep "common")
DOECHO "** checking permission for CommonLogger file"
DOECHO $(ls -l $sugar'/batch/common/CommonLogger.php')
DOECHO "** checking permission for Log.php in pear"
pear=$(pear config-get php_dir)
DOECHO $(ls -l $pear'/Log.php')
echo -e "$desc"

}

###################################################################
##### connectivity check for ISP by curl
###################################################################
CHKISP(){
desc="- connectivity check for ISP by curl"
FUNCDESC "$desc"
echo $'\n'
echo -e "$desc"

GETISPCONF
CHKISPuser
CHKISPdojo
}

##################################################
## read ISP backend url from httpd-ssl.conf
GETISPCONF(){
sdesc=" -- read ISP backend url from /opt/freeware/etc/httpd/conf/extra/httpd-ssl.conf"
SUBFUNCDESC "$sdesc"
echo -e "$sdesc"

ispsc=$(grep "/sc/" /opt/freeware/etc/httpd/conf/extra/httpd-ssl.conf | grep "ProxyPassReverse")
SHOWVALUE "/sc/ proxy setting in httpd-ssl.conf" "$ispsc"
IFS=" "; Array=($ispsc)
ispsc=${Array[2]}
echo -e "   isp /sc/: "$ispsc
DOECHO "isp /sc/:$ispsc"

ispdojoc=$(grep "/dojoC/" /opt/freeware/etc/httpd/conf/extra/httpd-ssl.conf | grep "ProxyPassReverse")
SHOWVALUE "/dojoC/ proxy setting in httpd-ssl.conf" "$ispdojoc"
IFS=" "; Array=($ispdojoc)
ispdojoc=${Array[2]}
echo -e "   isp /dojoap/: "$ispdojoc
DOECHO "isp /dojoap/:$ispdojoc"

}

##################################################
## /resources/userprofile - GET user information
CHKISPuser(){
sdesc=" -- /resources/userprofile - GET user information from ISP by user email: ""$uemail"
SUBFUNCDESC "$sdesc"
echo -e "$sdesc"

url=$ispsc""resources/userprofile?email="$uemail"
echo -e "   url: "$url
DOECHO "url:$url"
DOECHO "** Executing:curl '$url'  -s -S -i --cert $sc --key $sk --capath $cp"
DOECHO $'\n'
out=$(curl "$url" -s -S -i --cert $sc --key $sk --capath $cp)
DOECHO "$out"
SHOWSTATUS "$out"
}

##################################################
## dojoC/10.1.1/dojo/dojo.js - GET dojo.js
CHKISPdojo(){
sdesc=" -- /dojoC/10.1.1/dojo/dojo.js - GET dojo.js from ISP setting ibm_widget_dojoJSAbsolutePath"
SUBFUNCDESC "$sdesc"
echo -e "$sdesc"

url=$ispdojoc
echo -e "   url: "$url
DOECHO "url:$url"
DOECHO "** Executing:curl '$url'  -s -S -i --cert $sc --key $sk --capath $cp"
DOECHO $'\n'
out=$(curl "$url" -s -S -i --cert $sc --key $sk --capath $cp)
DOECHO "$out"
SHOWSTATUS "$out"
}

###################################################################
##### connectivity check for IEB/bluepages by curl
###################################################################
CHKBLUEPG(){
desc="- connectivity check for IEB/bluepages by curl"
FUNCDESC "$desc"
echo $'\n'
echo -e "$desc"

CHKBLUEPGuserdn
if [ "$userdn" = "" ];
  then
    CHKTSTBLUEPGuserdn
fi
CHKBLUEPGuserinfo
}
##################################################
## /bluepages - get user dn by email
CHKBLUEPGuserdn(){
sdesc=" -- /bluepages - GET user dn from bluepages by user email: ""$uemail"
SUBFUNCDESC "$sdesc"
echo -e "$sdesc"

root="$lu""/"
src="sc/lpde"
target="bluepages"
root=${root//$src/$target}

url=$root"/BpHttpApisv3/slaphapi?ibmperson/mail=""$uemail"".list,printable/bytext?uid"
echo -e "   url: "$url
DOECHO "url:$url"
DOECHO "** Executing:curl '$url' -s -S -i --cert $sc --key $sk --cacert ieb_bundle.crt"
DOECHO $'\n'
out=$(curl "$url" -s -S -i --cert $sc --key $sk --cacert ieb_bundle.crt)
DOECHO "$out"
SHOWSTATUS "$out"

case "$status" in
 *200*)
  userdn="${out#*dn: }"
  if [ ${#userdn} -eq ${#out} ]; then
    userdn=""
  else 
    userdn="${userdn%uid: *}"
    userdn="$(echo "$userdn" |  tr -d '[\n]')"

    uid="${out#*uid: }"
    uid="${uid%# *}"
    uid="$(echo "$uid" |  tr -d '[\n]')"
  fi
;;

esac

echo -e "   * userdn: "$userdn
echo -e "   * uid: "$uid
}

CHKBLUEPGuserinfo(){
##################################################
## /bluepages - get
sdesc=" -- /bluepages - GET user information for "$uid" from bluepage"
SUBFUNCDESC "$sdesc"
echo -e "$sdesc"

url=$root"/BpHttpApisv3/slaphapi?ibmperson/uid="$uid
echo -e "   url: "$url
DOECHO "url:$url"
DOECHO "** Executing:curl '$url' -s -S -i --cert $sc --key $sk --cacert ieb_bundle.crt"
DOECHO $'\n'
out=$(curl "$url" -s -S -i --cert $sc --key $sk --cacert ieb_bundle.crt)
DOECHO "$out"
case "$out" in
*entry*)
    msg="   * bluepages returned data for ""$uid"
    DOECHO "$msg"
    echo -e "$msg"
    ;;
*)
    msg="   * bluepages failed to find ""$uid"
    DOECHO "$msg"
    echo -e "$msg"
    ;;
esac
}

##################################################
## /tstbluepages - get user dn by email
CHKTSTBLUEPGuserdn(){
sdesc=" -- tstbluepages - GET user dn from tstbluepages by user email: ""$uemail"
SUBFUNCDESC "$sdesc"
echo -e "$sdesc"

url="http://tstbluepages.mkm.can.ibm.com/BpHttpApisv3/slaphapi?ibmperson/mail=""$uemail"".list,printable/bytext?uid"
echo -e "   url: "$url
DOECHO "url:$url"
DOECHO "** Executing:curl '$url' -s -S -i --cert $sc --key $sk --cacert ieb_bundle.crt"
DOECHO $'\n'
out=$(curl "$url" -s -S -i --cert $sc --key $sk --cacert ieb_bundle.crt)
DOECHO "$out"
SHOWSTATUS "$out"

case "$status" in
 *200*)
  userdn="${out#*dn: }"
  userdn="${userdn%uid: *}"
  userdn="$(echo "$userdn" |  tr -d '[\n]')"

  uid="${out#*uid: }"
  uid="${uid%# *}"
  uid="$(echo "$uid" |  tr -d '[\n]')"
;;

esac

echo -e "   * userdn: "$userdn
echo -e "   * uid: "$uid
}


############################################################################
##### connectivity check for IEB/LPDE by curl
############################################################################
CHKLPDE(){
desc="- connectivity check for IEB/LPDE by curl"
FUNCDESC "$desc"
echo $'\n'
echo -e "$desc"

dn="X-SFA-Login: ""$userdn"
xclient="X-Client: SalesConnect"
hdct="Content-Type: application/x-www-form-urlencoded"

CHKLPDElpde
CHKLPDELoginController
CHKLPDELPDEController
}
##################################################
## /lpde - post
CHKLPDElpde(){
sdesc=" -- /lpde - POST empty body to get session cookie: "$lc
SUBFUNCDESC "$sdesc"
echo -e "$sdesc"

url=$lu"/sales/gss/lpde"
echo -e "   url: "$url
DOECHO "url:$url"
DOECHO "** Executing:curl '$url' -H '$dn' -H '$hdct' -H '$xclient' -s -S -i --cert $sc --key $sk --cacert ieb_bundle.crt"
DOECHO $'\n'
out=$(curl "$url" -H "$dn" -H "$hdtc" -H "$xclient" -s -S -i --cert $sc --key $sk --cacert ieb_bundle.crt)
DOECHO "$out"
SHOWSTATUS "$out"
SHOWCOOKIE "$out"
}

##################################################
## /LoginController - post
CHKLPDELoginController(){
sdesc=" -- /LoginController - POST to register cookie: "$lc
SUBFUNCDESC "$sdesc"
echo -e "$sdesc"

url=$lu"/sales/gss/lpde/LoginController"
echo -e "   url: "$url
DOECHO "url:$url"
DOECHO "** Executing:curl '$url' -H '$dn' -H '$lcookie' -H '$hdct' -H '$xclient' -s -S -i -d 'actions=getLoginDetails' --cert $sc --key $sk --cacert ieb_bundle.crt"
DOECHO $'\n'
out=$(curl "$url" -H "$dn" -H "$lcookie" -H "$hdct" -H "$xclient" -s -S -i --cert $sc --key $sk --cacert ieb_bundle.crt)
DOECHO "$out"
SHOWSTATUS "$out"
}

##################################################
## /LPDEController - post
CHKLPDELPDEController(){
sdesc=" -- /LPDEController - POST query data to get BP recommendations: "$lc
SUBFUNCDESC "$sdesc"
echo -e "$sdesc"

url=$lu"/sales/gss/lpde/LPDEController"
echo -e "   url: "$url
DOECHO "url:$url"
pbody="crmInstance=US01SIEBEL&opptyid=FK-A8TLV12&country=GB&province=&city=ABERLOUR ON SPEY&zipCode=AB38 9PD&sector=GB LE&subsector=&covType=T&territory=T0000790&group=B7000&brand=AIM&level20=WFAA&level30=&product=WFAA&offer1=WFAA&offer2=&offer3=&offer4=&Acct=Other&custNo=na&issuingCountryCode=na&indSol=34&siteID=S004TVH6QW&currency=USD&leadValue=1000&bpRequested=None&bpsels=0&zipInput=na&cityInput=na&oi_source=&hJSPName=index&hButtonMode=search&Opp_SalesStage=03&Opp_OISource=BRSP"

pbody="crmInstance=US01SIEBEL&opptyid=2Y-4LR8YRR&country=PE&province=&city=LIMA&zipCode=12&sector=GB LE&subsector=&covType=T&territory=T0001644&clientId=DC01ULGB&group=B7000&brand=DM&level20=IMIS&level30=&product=IMIS&offer1=IMIS&offer2=&offer3=&offer4=&Acct=Other&custNo=na&issuingCountryCode=na&indSol=34&siteID=S001PF1FFN&currency=USD&leadValue=9800&bpRequested=None&bpsels=0&zipInput=na&cityInput=na&oi_source=&hJSPName=index&hButtonMode=search&Opp_SalesStage=03&Opp_OISource=BCS"

pbody="US01SIEBEL&opptyid=6P-WC3VOV7&country=US&province=FL&city=ORLANDO&zipCode=32803-4390&sector=Sector&subsector=DIST&covType=A&territory=A0001834&clientId=DC02L0V4&group=B7000&brand=AIM&level20=WFAA&level30=&product=WFAA&offer1=WFAA&offer2=&offer3=&offer4=&Acct=Other&custNo=na&issuingCountryCode=na&indSol=1R&siteID=S003QCU3VN&currency=USD&leadValue=1000&bpRequested=None&bpsels=0&zipInput=na&cityInput=na&oi_source=&hJSPName=index&hButtonMode=search&Opp_SalesStage=03&Opp_OISource=BRSP"

pbody="crmInstance=US01SIEBEL&opptyid=MO-CS8H7GN&country=GB&province=&city=ASHFORD&zipCode=TN25 4BF&sector=GB LE&subsector=&covType=T&territory=T0002906&clientId=DC02V3SN&group=B7000&brand=AIM&level20=WFAA&level30=&product=WFAA&offer1=WFAA&offer2=&offer3=&offer4=&Acct=Other&custNo=na&issuingCountryCode=na&indSol=34&siteID=S003Z42Y2G&currency=USD&leadValue=1550&bpRequested=None&bpsels=0&zipInput=na&cityInput=na&oi_source=&hJSPName=index&hButtonMode=search&Opp_SalesStage=03&Opp_OISource=BRSP"

pbody="crmInstance=US01SIEBEL&opptyid=PO-OFNZB9F&country=AU&province=ACT&city=CIVIC SQUARE&zipCode=2600&sector=GB LE&subsector=&covType=T&territory=T0001744&clientId=DC01Z1L0&group=B7000&brand=AIM&level20=WFAA&level30=SW/WASND&product=WFAA&offer1=WFAA&offer2=SW/WASND&offer3=&offer4=&Acct=Other&custNo=na&issuingCountryCode=na&indSol=34&siteID=S007AA59EX&currency=USD&leadValue=620.000087&bpRequested=None&bpsels=0&zipInput=na&cityInput=na&oi_source=&hJSPName=index&hButtonMode=search&Opp_SalesStage=03&Opp_OISource=BRSP"

pbody="crmInstance=US01SIEBEL&opptyid=IA-9YGBTTS&country=GB&province=&city=London&zipCode=SE22 8SU&sector=GB MM&subsector=&covType=T&territory=&clientId=&group=B7000&brand=AIM&level20=WFAA&level30=&product=WFAA&offer1=WFAA&offer2=&offer3=&offer4=&Acct=Other&custNo=na&issuingCountryCode=na&indSol=32&siteID=S003AEQPCE&currency=USD&leadValue=1550.000698&bpRequested=None&bpsels=0&zipInput=na&cityInput=na&oi_source=&hJSPName=index&hButtonMode=search&Opp_SalesStage=03&Opp_OISource=BRSP"

DOECHO "** Executing:curl '$url' -H '$dn' -H '$lcookie' -H '$hdct' -H '$xclient' -s -S -i -d '$pbody' --cert $sc --key $sk --cacert ieb_bundle.crt"
DOECHO $'\n'
out=$(curl "$url" -H "$dn" -H "$lcookie" -H "$hdct" -H "$xclient" -s -S -i -d "$pbody" --cert $sc --key $sk --cacert ieb_bundle.crt)
DOECHO "$out"
SHOWSTATUS "$out"
case "$out" in
*pageInfo*)
    msg="   ** BP recommendation data returned."
    DOECHO "$msg"
    echo -e "$msg"
    ;;
*)
    msg="   ** Failed to get BP recommendation data."
    DOECHO "$msg"
    echo -e "$msg"
    ;;
esac

}

##############################################################################
##### connectivity check for IEB/Connections by curl
##############################################################################
CHKCONNECTIONS(){
desc="- connectivity check for IEB/Connections by curl"
FUNCDESC "$desc"
echo $'\n'
echo -e "$desc"

DOECHO "functional id: "$femail
DOECHO "functional id cnum: "$fcn
hd="X-SFA-Login: ""$userdn"
hdct="Content-Type: application/atom+xml"
commname="TestComm""("$(date +"%T-%m/%d/%Y")")_"$(hostname)

CHKCONNECTIONSprofiles $femail fuid
CHKCONNECTIONSprofiles $uemail uuid
CHKCONNECTIONCommCreate
CHKCONNECTIONCommAddWidget
CHKCONNECTIONCommAddMem
CHKCONNECTIONCommList
CHKCONNECTIONCommDel
}
##################################################
## profiles - get
CHKCONNECTIONSprofiles(){
sdesc=" -- profiles - GET profile for functional id: "$1
SUBFUNCDESC "$sdesc"
echo -e "$sdesc"

param="/profiles/atom/profile.do?email="$1
url=$cu$param
echo -e "   url: "$url
DOECHO "url:$url"
DOECHO "** Executing:curl '$url' -H '$hd' -s -S -i --cert $sc --key $sk --cacert ieb_bundle.crt"
DOECHO $'\n'
out=$(curl "$url" -H "$dn" -s -S -i --cert $sc --key $sk --cacert ieb_bundle.crt)
DOECHO "$out"
SHOWSTATUS "$out"
GETUID "$out" $2

}

#################################################
## communities - POST to create a private community
CHKCONNECTIONCommCreate(){
echo $'\r'

sdesc=" -- communities - POST to create private ""$commname"" community for ""$uemail""'s community"

SUBFUNCDESC "$sdesc"
echo -e "$sdesc"

param="/communities/service/atom/communities/my"
url=$cu$param
echo -e "   url: "$url
DOECHO "url:$url"
pbody="<?xml version='1.0' encoding='UTF-8'?><entry xmlns='http://www.w3.org/2005/Atom' xmlns:app='http://www.w3.org/2007/app' xmlns:snx='http://www.ibm.com/xmlns/prod/sn'><title type='text'>""$commname""</title><summary type='text'>ignored</summary><content type='html'></content><category term='community' scheme='http://www.ibm.com/xmlns/prod/sn/type'></category>
<snx:communityType>private</snx:communityType></entry>"

DOECHO "** Executing:curl '$url' -H '$hd' -H '$hdct' -s -S -i -d '$pbody' --cert $sc --key $sk --cacert ieb_bundle.crt"
DOECHO $'\n'
out=$(curl "$url" -H "$hd" -H "$hdct" -s -S -i -d "$pbody" --cert $sc --key $sk --cacert ieb_bundle.crt)
DOECHO "$out"
SHOWSTATUS "$out"
GETLOC "$out"
}

##################################################
## communities - POST with overrideing PUT to add Blog widget to the community
CHKCONNECTIONCommAddWidget(){
sdesc=" -- communities - PUT to update ""$commname"" community"
SUBFUNCDESC "$sdesc"
echo -e "$sdesc"

## param="$commurl"
param="/communities/addWidget.do?resourceId="$commid"&uiLocation=col2&unhide=false&widgetDefId=Blog"
url=$cu$param
echo -e "   url: "$url
DOECHO "url:$url"
DOECHO "** Executing:curl '$url' -H '$hd' -H '$hdtc' -H 'X-HTTP-Method-Override: PUT' -H 'Pragma: WWW-Authentic
ate=XHR' -H 'X-Requested-With: XMLHttpRequest' -s -S -i -d '' --cert $sc --key $sk --cacert ieb_bundle.crt"
DOECHO $'\n'
out=$(curl "$url" -H "$hd" -H "$hdtc" -H 'X-HTTP-Method-Override: PUT' -H 'Pragma: WWW-Authenticate=XHR' -H 'X-
Requested-With: XMLHttpRequest' -s -S -i -d '' --cert $sc --key $sk --cacert ieb_bundle.crt)
DOECHO "$out"
SHOWSTATUS "$out"
}

#################################################
## communities - POST to add/delete fid as a member
CHKCONNECTIONCommAddMem(){
echo $'\r'

sdesc=" -- communities - POST to add/delte ""$femail""as owner for ""$commname"

SUBFUNCDESC "$sdesc"
echo -e "$sdesc"

if [ "$fuid" = "" ];
   then
      echo -e " uid for functional id is empty!"
      DOECHO "fuid is empty."

      return
fi


param="/communities/service/atom/community/members?communityUuid=""$commid"
url=$cu$param
echo -e "   url: "$url
DOECHO "url:$url"
pbody="<?xml version='1.0' encoding='UTF-8'?><entry xmlns='http://www.w3.org/2005/Atom' xmlns:snx='http://www.ibm.com/xmlns/prod/sn' xmlns:default='http://www.w3.org/1999/xhtml'><title type='text'></title><summary type='text'></summary><category term='person' scheme='http://www.ibm.com/xmlns/prod/sn/type'/><snx:orgId xmlns:snx='http://www.ibm.com/xmlns/prod/sn'/><content type='xhtml'></content><contributor><email>""$femail""</email><snx:userid>""$fuid""</snx:userid></contributor><snx:role component='http://www.ibm.com/xmlns/prod/sn/communities'>owner</snx:role></entry>"

DOECHO "** Executing:curl '$url' -H '$hd' -H '$hdct' -H 'X-HTTP-Method-Override: PUT' -s -S -i -d '$pbody' --cert $sc --key $sk --cacert ieb_bundle.crt"
DOECHO $'\n'
out=$(curl "$url" -H "$hd" -H "$hdct" -H 'X-HTTP-Method-Override: PUT' -s -S -i -d "$pbody" --cert $sc --key $sk --cacert ieb_bundle.crt)
DOECHO "$out"
SHOWSTATUS "$out"
#GETLOC "$out"

param="/communities/service/atom/community/members?communityUuid=""$commid""&email=""$femail"
url=$cu$param
echo -e "   url: "$url
DOECHO "url:$url"

DOECHO "** Executing:curl '$url' -H '$hd' -H '$hdct' -s -S -i -X DELETE --cert $sc --key $sk --cacert ieb_bundle.crt"
DOECHO $'\n'
out=$(curl "$url" -H "$hd" -H "$hdct" -s -S -i -X DELETE --cert $sc --key $sk --cacert ieb_bundle.crt)
DOECHO "$out"
SHOWSTATUS "$out"
#GETLOC "$out"

}

##################################################
## communites - get community list
CHKCONNECTIONCommList(){
sdesc=" -- communities - GET for ""$uemail""'s community list "
SUBFUNCDESC "$sdesc"
echo -e "$sdesc"

param="/communities/service/atom/communities/my"
url=$cu$param
echo -e "   url: "$url
DOECHO "url:$url"
DOECHO "#Executing:curl '$url' -H '$hd' -s -S -i --cert $sc --key $sk --cacert ieb_bundle.crt"
out=$(curl "$url" -H "$hd" -s -S -i --cert $sc --key $sk --cacert ieb_bundle.crt)
DOECHO $'\n'
DOECHO "$out"
SHOWSTATUS "$out"
case "$out" in
*TestCom*)
    msg="   ** Found ""$commname"" community"
    DOECHO "$msg"
    echo "$msg"
    ;;
*)
    msg="   ** Failed to find ""$commname"
    DOECHO "$msg"
    echo "$msg"
    ;;
esac

#echo -n -e "  ** Community testing is done. Press Enter key to delete test community: ""$commname"
#read action

}

##################################################
## communites - delete TestComm community
CHKCONNECTIONCommDel(){
sdesc=" -- communities - DELETE ""$commname"" from ""$uemail""'s community list "
SUBFUNCDESC "$sdesc"
echo -e "$sdesc"

param="/communities/service/atom/community/instance?communityUuid=""$commid"
url=$cu$param
echo -e "   url: $url"
DOECHO "url:$url"
DOECHO "#Executing:curl '$url' -H '$hd' -s -S -i -X DELETE --cert $sc --key $sk --cacert ieb_bundle.crt"
out=$(curl "$url" -H "$hd" -s -S -i -X DELETE --cert $sc --key $sk --cacert ieb_bundle.crt)
DOECHO "$out"
SHOWSTATUS "$out"
}

##############################################################################
##### ldaps check - check TLS_CACERT set for ldap,check pem,echo permissions  
##############################################################################
chkldaps(){
desc="- ldaps check - TLS_CACERT and LDAP server certificate"
FUNCDESC "$desc"
echo $'\n'
echo -e "$desc"
ldapc="/etc/openldap/ldap.conf"  #LDAP Configuration file
set -- "$ldapc"
if [[ -e $ldapc ]];
	then
	DOECHO $(ls -l $ldapc)
	DOECHO "** checking TLS_CACERT is set for ldap"
	tlsc=$(grep "TLS_CACERT" $ldapc) 
	SHOWVALUE "TLS_CACERT" "$tlsc"
	DOECHO "** checking ldap certificate"
   	if [ "$tlsc" = "" ];
	   then
	      DOECHO "TLS_CACERT *** NOT DEFINED *** in $ldapc : LDAPS not configured with certificate"
	else
	ldap_pem=$(echo $tlsc | cut -f2 -d " ")
	SHOWVALUE "LDAP_PEM" "$ldap_pem"
	DOECHO $(ls -l $ldap_pem)
	fi
else
	SHOWVALUE "ldapc" "$ldapc"
	DOECHO "$ldapc *** NOT FOUND! ***"
fi
}

##############################################################################
##### System time check - use Network Time Protocol(NTP) to check if system
##### time deviates from internet time beyond the acceptable range. 
##############################################################################
CHKSYSTEMTIME(){
desc="- System Time check "
FUNCDESC "$desc"
echo $'\n'
echo -e "$desc"

limit=120
isOffset=""

offsetLine=$(ntpdate -q 129.132.2.21 | tail -1) 
IFS=" "; words=($offsetLine)
for word in "${words[@]}"
do
        # extract offset number
        if [ "$isOffset" = "y" ]
        then
           offset=$(echo "$word" | tr -d '-')
           break
        fi

	case "$word" in
           "offset")
              isOffset=y
              ;;
        esac
done
DOECHO "System time is $offset seconds deviating from internet time..."

# change offset to integer to do arithmatic comparison
if [  ${offset%.*} -ge $limit ]
	then
		DOECHO "WARNING: The deviation is beyond the $limit seconds range, please investigate"
 	else
		DOECHO "OK... The deviation is within the $limit seconds range."
fi
}

####################
##### MAIN 
####################
INIT
CHKSKEY
CHKSCERT
CHKDCERT
CHKCAPATH
#CHKLOGPKG
#CHKISP
CHKBLUEPG

if [ "$userdn" = "" ];
  then
    echo -e "**invalid user, skipping lpde and connections test**"
else
  CHKLPDE
#  CHKCONNECTIONS
fi

#chkldaps
#CHKSYSTEMTIME

if [ "$3" != "" ]; then
echo -e "\n\n**Testing IEB connectivity every "$4" seconds - "$3" times"

(for (( i=$3; i>0; i--)); do
  sleep $4 &

  echo -e "\n**Testing remaining "$i" of "$3

  CHKBLUEPGuserdn
  if [ "$userdn" = "" ];
    then
      echo -e "**invalid user, skipping lpde and connections test**"
  else
    CHKLPDElpde
    CHKCONNECTIONSprofiles $uemail uuid

  fi
  wait
  done)
fi

echo $'\n'
echo -e " ** chk.out was generated with more detail logging!"
ls -l chk.out
