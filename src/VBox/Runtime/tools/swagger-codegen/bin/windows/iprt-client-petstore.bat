set executable=.\modules\swagger-codegen-cli\target\swagger-codegen-cli.jar

If Not Exist %executable% (
  mvn clean package
)

REM set JAVA_OPTS=%JAVA_OPTS% -Xmx1024M -DloggerPath=conf/log4j.properties
set ags=generate  --artifact-id "iprt-petstore-client" -i modules\swagger-codegen\src\test\resources\2_0\petstore.yaml -l iprt -o samples\client\petstore\iprt

java %JAVA_OPTS% -jar %executable% %ags%
