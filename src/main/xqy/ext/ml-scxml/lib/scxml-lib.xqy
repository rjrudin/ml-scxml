xquery version "1.0-ml";

module namespace mlsc = "http://marklogic.com/scxml";

import module namespace sem = "http://marklogic.com/semantics" at "/MarkLogic/semantics.xqy";

declare namespace sc = "http://www.w3.org/2005/07/scxml";

(:
Move persistence functions into a separate library? 
:)
declare function start($statechart-id as xs:string) as xs:string {
  let $sc := find-statechart($statechart-id)
  let $initial-state := ($sc/(sc:state|sc:final)[@id = $sc/@initial], $sc/sc:state[1])[1]
  
  let $instance-id := new-instance-id()

  let $instance := element mlsc:instance {
    attribute created-date-time {fn:current-dateTime()},
    element mlsc:statechart-id {$statechart-id},
    element mlsc:instance-id {$instance-id},
    element mlsc:state {fn:string($initial-state/@id)},
    $sc/sc:datamodel
  }
  
  let $instance := enter-state($initial-state, $sc, $instance)
  let $uri := build-instance-uri($instance-id)
  return (
    xdmp:document-insert($uri, $instance),
    $instance-id
  )
};

declare function trigger-event(
  $instance-id as xs:string,
  $event as xs:string
  ) as element(mlsc:instance)
{
  let $instance := get-instance($instance-id)
  let $sc := find-statechart(get-statechart-id($instance))
  let $state := $sc/sc:state[@id = $instance/mlsc:state/fn:string()]
  let $_ := xdmp:log($state)
  (: TODO Lots of matching logic to add here :)
  let $transition := $state/sc:transition[@event = $event][1]
  let $_ := xdmp:log($transition)
  let $new-state := $sc/sc:state[@id = $transition/@target][1]
  let $_ := xdmp:log($new-state)
  let $new-instance := enter-state($new-state, $sc, $instance)
  let $_ := xdmp:node-replace($instance, $new-instance)
  return $new-instance
};

declare function enter-state(
  $state as element(sc:state), 
  $sc as element(sc:scxml), 
  $instance as element(mlsc:instance)
  ) as element(mlsc:instance)
{
  let $datamodel := $instance/sc:datamodel
  let $_ := 
    for $el in $state/sc:onentry/element()
    return typeswitch ($el)
      case element(sc:log) return xdmp:log(xdmp:eval($el/@expr))
      case element(sc:assign) return

        let $location := $el/@location/fn:string()
        let $var := fn:substring(fn:tokenize($location, "/")[1], 2)
        let $path := "/" || fn:substring-after($location, "/")
        let $expr := $el/@expr/fn:string()
        
        let $stylesheet := <xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:sc="http://www.w3.org/2005/07/scxml">
        <xsl:template match="*">
            <xsl:copy>
              <xsl:copy-of select="attribute::*" />
              <xsl:apply-templates />
            </xsl:copy>
          </xsl:template>
        <xsl:template match="sc:data[@id = '{$var}']{$path}">
          <xsl:copy>
            <xsl:value-of select="{$expr}"/>
          </xsl:copy>
        </xsl:template>
        </xsl:stylesheet>
        return xdmp:set($datamodel, xdmp:xslt-eval($stylesheet, $datamodel))
        
      default return ()

  return element {fn:node-name($instance)} {
    $instance/@*,
    for $kid in $instance/element()
    return typeswitch($kid)
      case element(mlsc:state) return element mlsc:state {$state/@id/fn:string()}
      case element(sc:datamodel) return $datamodel
      default return $kid
  }
};

declare function get-instance($id as xs:string) as element(mlsc:instance)?
{
  let $uri := build-instance-uri($id)
  where fn:doc-available($uri)
  return fn:doc($uri)/mlsc:instance
};

(:
TODO Will want this to be overrideable, in terms of where the statechart is expected to be.
:)
declare function find-statechart($statechart-id as xs:string) as element(sc:scxml)
{
  xdmp:eval("
    xquery version '1.0-ml';
    declare variable $statechart-id as xs:string external;
    let $uri := fn:concat('/ext/ml-scxml/statecharts/' || $statechart-id || '.xml')
    return fn:doc($uri)",
    (xs:QName("statechart-id"), $statechart-id),
    <options xmlns="xdmp:eval">
      <database>{xdmp:modules-database()}</database>
    </options>
  )/sc:scxml
};

declare function build-instance-uri($instance-id as xs:string) as xs:string
{
  "/ml-scxml/instances/" || $instance-id || ".xml"
};

declare function new-instance-id() as xs:string
{
  (: TODO Is this callable without the semantics license? :)
  sem:uuid-string()
};

declare function get-instance-id($instance as element(mlsc:instance)) as xs:string
{
  $instance/mlsc:instance-id/fn:string()
};

declare function get-statechart-id($instance as element(mlsc:instance)) as xs:string
{
  $instance/mlsc:statechart-id/fn:string()
};

declare function get-state($instance as element(mlsc:instance)) as xs:string
{
  $instance/mlsc:state/fn:string()
};
