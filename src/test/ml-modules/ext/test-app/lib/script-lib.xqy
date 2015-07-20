xquery version "1.0-ml";

module namespace test = "urn:testapp";

import module namespace mlsc = "http://marklogic.com/scxml" at "/ext/ml-scxml/lib/scxml-lib.xqy";
import module namespace session = "http://marklogic.com/scxml/session" at "/ext/ml-scxml/lib/session-lib.xqy";

declare namespace sc = "http://www.w3.org/2005/07/scxml";

(:
This shows an example of modifying the datamodel element in the instance document in the session map. And we insert
a test document for good measure too.
:)
declare function update($session as map:map) as empty-sequence()
{
  xdmp:log("ml-scxml test update function called"),
  
  xdmp:document-insert("/ml-scxml/test/123.xml", <helloWorld/>, 
    (xdmp:permission("rest-reader", "read"), xdmp:permission("rest-writer", "update"))
  ),
  
  let $instance := session:get-instance($session)
  let $datamodel := mlsc:get-datamodel($instance)
  
  let $new-datamodel := element sc:datamodel {
    for $data in $datamodel/sc:data
    return element sc:data {
      $data/@*,
      $data/node(),
      if ($data/@id = "ticket") then 
        <newElement>This was inserted via a script block</newElement>
      else ()  
    }
  }
  
  return session:set-instance(
    $session,
    mlsc:rebuild-with-new-datamodel($instance, $new-datamodel)
  )
};
