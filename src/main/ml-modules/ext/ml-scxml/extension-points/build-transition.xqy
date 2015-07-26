xquery version "1.0-ml";

(:
Extension point for building a transition that is then persisted on the instance document as a record of that 
transition occurring. I don't anticipate that ml-scxml will have dependencies on the data that is recorded here - this
is really for auditing/analytics.
:)

module namespace mlscxp = "http://marklogic.com/scxml/extension-points";

declare namespace mlsc = "http://marklogic.com/scxml";
declare namespace sc = "http://www.w3.org/2005/07/scxml";


(:
$source-state and $transition will be empty in case the instance just started up.
:)
declare function build-transition(
  $source-state as element()?,
  $transition as element(sc:transition)?,
  $entered-states as element()+,
  $session as map:map
  ) as element(mlsc:transition)
{
  <mlsc:transition date-time="{fn:current-dateTime()}">
    {
    let $event := $transition/@event/fn:string()
    where $event
    return attribute event {$event},
    
    if ($source-state) then 
      <mlsc:from state="{fn:string($source-state/@id)}"/>
    else (),
    
    for $state in $entered-states
    return <mlsc:to state="{fn:string($state/@id)}"/> 
    }
  </mlsc:transition>
};
