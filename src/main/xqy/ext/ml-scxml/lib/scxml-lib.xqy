xquery version "1.0-ml";

(:
This library is intended to not perform any persistence operations; it just implements SCXML functionality.
:)

module namespace mlsc = "http://marklogic.com/scxml";

declare namespace sc = "http://www.w3.org/2005/07/scxml";

declare function start(
  $machine-id as xs:string,
  $machine as element(sc:scxml),
  $instance-id as xs:string
  ) as element(mlsc:instance)
{
  let $initial-state := ($machine/(sc:state|sc:final)[@id = $machine/@initial], $machine/sc:state[1])[1]
  
  let $instance := element mlsc:instance {
    attribute created-date-time {fn:current-dateTime()},
    element mlsc:machine-id {$machine-id},
    element mlsc:instance-id {$instance-id},
    element mlsc:state {fn:string($initial-state/@id)},
    $machine/sc:datamodel
  }
  
  return enter-state($initial-state, $machine, $instance)
};

declare function trigger-event(
  $instance as element(mlsc:instance),
  $machine as element(sc:scxml),
  $event as xs:string
  ) as element(mlsc:instance)
{
  let $state := $machine/sc:state[@id = $instance/mlsc:state/fn:string()]
  (: TODO Lots of matching logic to add here :)
  let $transition := $state/sc:transition[@event = $event][1]
  let $new-state := $machine/sc:state[@id = $transition/@target][1]
  return enter-state($new-state, $machine, $instance)
};

declare function enter-state(
  $state as element(sc:state), 
  $machine as element(sc:scxml), 
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

declare function get-instance-id($instance as element(mlsc:instance)) as xs:string
{
  $instance/mlsc:instance-id/fn:string()
};

declare function get-machine-id($instance as element(mlsc:instance)) as xs:string
{
  $instance/mlsc:machine-id/fn:string()
};

declare function get-state($instance as element(mlsc:instance)) as xs:string
{
  $instance/mlsc:state/fn:string()
};
