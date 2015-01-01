package com.marklogic.scxml.datamodel;

import org.junit.Test;

import com.jayway.restassured.RestAssured;
import com.jayway.restassured.response.Response;
import com.marklogic.scxml.AbstractScxmlTest;
import com.marklogic.test.jdom.Fragment;

public class AssignTest extends AbstractScxmlTest {

    @Test
    public void test() {
        Response r = RestAssured.post("/v1/resources/scxml?rs:statechartId=assign");
        String instanceId = r.jsonPath().getString("instanceId");

        r = RestAssured.get("/v1/resources/scxml?rs:instanceId=" + instanceId);
        Fragment instance = parse(r.asString());
        instance.prettyPrint();
    }
}
