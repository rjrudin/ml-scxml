What is ml-scxml?
========

ml-scxml is an implementation of the [SCXML](http://www.w3.org/TR/scxml/) spec written in XQuery on MarkLogic. 

What ml-scxml provides:

1. A set of libraries that can be included in your application that conform to the lastest SCXML spec.
2. A REST API endpoint for starting new workflow instances and firing events.

What ml-scxml doesn't provide:

1. A GUI for authoring and managing state machine definitions.
2. A GUI for managing state machine instances.

What would I use this?
========

If you think you can model your workflows / business processes / etc using SCXML (if you can define a process as a series of states and transitions, then the answer is "yes", and it's likely that you can do this), and if you want to track workflow instance data in MarkLogic instead of in a separate relational database, then you should consider using ml-scxml. Feel free to contact me to discuss further.

What dependencies does ml-scxml have?
========
I'm developing ml-scxml on ML8, but odds are very good that it will run on ML7, and possibly even ML6. 

ml-scxml exposes a REST API endpoint, but you don't need to use it, so you don't even need to use the REST API.

There's no dependency on anything else.

How do I use ml-scxml?
========
More to come on this soon, but here are the basics:

1. Load your SCXML documents (your state machine definitions) into /ext/ml-scxml/machines
2. To create a new instance of a state machine, make a POST to /v1/resources/scxml?rs:machineId=(name of your machine), where "name of your machine" matches your machine module filename minus the ".xml"
3. To fire an event into an existing instance, make a POST to /v1/resource/scxml?rs:instanceId=(the instance ID)&rs:event=(the event name).

For examples, see https://github.com/rjrudin/ml-scxml/tree/master/src/test/resources/machines. The only other docs are right now are all the [JUnit test cases](https://github.com/rjrudin/ml-scxml/tree/master/src/test/java/com/marklogic/scxml).
