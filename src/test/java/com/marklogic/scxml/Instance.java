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

    public void assertActiveState(String state) {
        assertElementValue("/mlsc:instance/mlsc:active-states/mlsc:active-state", state);
    }

    public void assertActiveStates(String... states) {
        for (String state : states) {
            assertActiveState(state);
        }
    }

    public void assertDatamodelElementExists(String dataId, String xpath) {
        String path = format("/mlsc:instance/sc:datamodel/sc:data[@id = '%s']/%s", dataId, xpath);
        assertElementExists(path);
    }

    public void assertTransitionExists(String fromState, String toState) {
        assertElementExists(format(
                "/mlsc:instance/mlsc:transitions/mlsc:transition[mlsc:from/@state = '%s' and mlsc:to/@state = '%s' and @date-time != '']",
                fromState, toState));
    }
}
