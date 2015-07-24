package com.marklogic.scxml;

import com.marklogic.junit.Fragment;

public class Instance extends Fragment {

    public Instance(Fragment other) {
        super(other);
    }

    public void assertMachineId(String machineId) {
        assertElementValue("/mlsc:instance/mlsc:machine-id", machineId);
    }

    public void assertInstanceId(String instanceId) {
        assertElementValue("/mlsc:instance/mlsc:instance-id", instanceId);
    }

    public void assertCurrentState(String state) {
        assertElementValue("/mlsc:instance/mlsc:current-states/mlsc:current-state", state);
    }

    public void assertCurrentStates(String... states) {
        for (String state : states) {
            assertCurrentState(state);
        }
        String xpath = "/mlsc:instance/mlsc:current-states/mlsc:current-state[%d]";
        assertElementExists(format(xpath, states.length));
        assertElementMissing("Expected " + xpath + " to not exist", format(xpath, states.length + 1));
    }

    public void assertDatamodelElementExists(String dataId, String xpath) {
        String path = format("/mlsc:instance/sc:datamodel/sc:data[@id = '%s']/%s", dataId, xpath);
        assertElementExists(path);
    }

    /**
     * This is for transitions that occur when a state machine starts up, where there is no from state yet.
     * 
     * @param position
     * @param toState
     */
    public void assertTransitionExists(int position, String toState) {
        assertTransitionExists(position, null, null, toState);
    }

    public void assertTransitionExists(int position, String event, String fromState, String toState) {
        if (fromState == null || event == null) {
            assertElementExists(format(
                    "/mlsc:instance/mlsc:transitions/mlsc:transition[%d][not(mlsc:from) and mlsc:to/@state = '%s' and @date-time != '']",
                    position, toState));
        } else {
            assertElementExists(format(
                    "/mlsc:instance/mlsc:transitions/mlsc:transition[%d][@event = '%s' and @date-time != '' and mlsc:from/@state = '%s' and mlsc:to/@state = '%s']",
                    position, event, fromState, toState));
        }
    }

    public void assertTransitionCount(String message, int count) {
        String xpath = "/mlsc:instance/mlsc:transitions/mlsc:transition[%d]";
        assertElementExists(message, format(xpath, count));
        assertElementMissing(message, format(xpath, count + 1));
    }
}
