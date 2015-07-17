xquery version "1.0-ml";

module namespace test = "urn:testapp";

declare namespace mlsc = "http://marklogic.com/scxml";
declare namespace sc = "http://www.w3.org/2005/07/scxml";

(:
This shows an example of modifying the datamodel element, which ml-scxml will then toss back into the instance
document. And we insert a test document as well. 

TODO May expand this signature - perhaps take a map so anything can be tossed into it. Like a $context map.
:)
declare function update($datamodel as element(sc:datamodel)) as element(sc:datamodel)
{
  xdmp:log("ml-scxml test update function called"),
  
  xdmp:document-insert("/ml-scxml/test/123.xml", <helloWorld/>, 
    (xdmp:permission("rest-reader", "read"), xdmp:permission("rest-writer", "update"))
  ),
  
  <sc:datamodel>
    <sc:data id="ticket">
      <price>0</price>
      <newElement>This was inserted via a script block</newElement>
    </sc:data>
  </sc:datamodel>
};
