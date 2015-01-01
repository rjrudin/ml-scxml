package com.marklogic.scxml.datamodel;

import org.junit.Test;

import com.jayway.restassured.RestAssured;
import com.jayway.restassured.response.Response;
import com.marklogic.scxml.AbstractScxmlTest;

public class AssignTest extends AbstractScxmlTest {

    @Test
    public void test() {
        Response r = RestAssured.post("/v1/resources/scxml?rs:statechartId=assign");
        r.prettyPrint();
    }
}
