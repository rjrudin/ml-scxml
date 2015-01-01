package com.marklogic.scxml;

import java.util.List;

import org.jdom2.Namespace;

import com.marklogic.test.jdom.MarkLogicNamespaceProvider;

public class ScxmlNamespaceProvider extends MarkLogicNamespaceProvider {

    @Override
    protected List<Namespace> buildListOfNamespaces() {
        List<Namespace> list = super.buildListOfNamespaces();
        list.add(Namespace.getNamespace("mlsc", "http://marklogic.com/scxml"));
        list.add(Namespace.getNamespace("sc", "http://www.w3.org/2005/07/scxml"));
        return list;
    }
}
