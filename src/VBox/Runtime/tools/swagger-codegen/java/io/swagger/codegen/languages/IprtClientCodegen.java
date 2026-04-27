/* $Id: IprtClientCodegen.java 114031 2026-04-27 08:07:08Z knut.osmundsen@oracle.com $ */
/** @file
 * Swagger client IPRT code generator.
 */

/*
 * Copyright (C) 2018-2026 Oracle and/or its affiliates.
 *
 * This file is part of VirtualBox base platform packages, as
 * available from https://www.virtualbox.org.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation, in version 3 of the
 * License.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, see <https://www.gnu.org/licenses>.
 *
 * The contents of this file may alternatively be used under the terms
 * of the Common Development and Distribution License Version 1.0
 * (CDDL), a copy of it is provided in the "COPYING.CDDL" file included
 * in the VirtualBox distribution, in which case the provisions of the
 * CDDL are applicable instead of those of the GPL.
 *
 * You may elect to license modified versions of this file under the
 * terms and conditions of either the GPL or the CDDL or both.
 *
 * SPDX-License-Identifier: GPL-3.0-only OR CDDL-1.0
 */

package io.swagger.codegen.languages;

import java.io.File;
import java.lang.Exception;
import java.util.*;

import org.apache.commons.lang3.StringUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.samskivert.mustache.Escapers;
import com.samskivert.mustache.Mustache.Compiler;

import io.swagger.codegen.*;
import io.swagger.codegen.utils.ModelUtils;
import io.swagger.models.Model;
import io.swagger.models.Operation;
import io.swagger.models.Path;
import io.swagger.models.RefModel;
import io.swagger.models.Response;
import io.swagger.models.Swagger;
import io.swagger.models.parameters.HeaderParameter;
import io.swagger.models.parameters.Parameter;
import io.swagger.models.properties.*;
import io.swagger.models.properties.PropertyBuilder;
import io.swagger.util.Json; // for debugging


public class IprtClientCodegen extends AbstractCppCodegen
{
    public static final String PROJECT_NAME = "VirtualBox";
    public static final String PREFIX       = "IprtSwg";

    /** @name CLI options
     * @{ */
    public static final String CPP_NAMESPACE        = "cppNamespace";
    public static final String CPP_NAMESPACE_DESC   = "C++ namespace (namespace1[::namespace2[..]]) to put the generate code in.";
    public static final String CPP_NAMESPACE_DECLS  = "cppNamespaceDeclarations";
    protected String           m_cppNamespace       = "IprtSwg";

    public static final String KMK_DEPTH            = "kmkDepth";
    public static final String KMK_DEPTH_DESC       = "The kBuild SUB_DEPTH value.";
    protected String           m_kmkDepth           = "../../../../../..";

    public static final String KMK_TARGET           = "kmkTarget";
    public static final String KMK_TARGET_DESC      = "The kBuild target name.";
    protected String           m_kmkTarget          = "MyLibrary";

    public static final String KMK_TEMPLATE         = "kmkTemplate";
    public static final String KMK_TEMPLATE_DESC    = "The kBuild template name";
    protected String           m_kmkTemplate        = "VBoxR3Dll";

    public static final String OCI_REQ_SIGN         = "ociReqSign";
    public static final String OCI_REQ_SIGN_DESC    = "OCI request signing (https://docs.cloud.oracle.com/iaas/Content/API/Concepts/signingrequests.htm)";
    protected boolean          m_fOciReqSign        = false;

    public static final String COPYRIGHT_STATEMENT       = "copyrightStatement";
    public static final String COPYRIGHT_STATEMENT_DESC  = "Copyright statement line";

    public static final String COPYRIGHT_LINE       = "copyrightLine";
    public static final String COPYRIGHT_LINE_DESC  = "Additional copyright statement line #";
    /** @} */

    /** @name Vendor extensions
     * @{ */
    public static final String X_IS_DELETE_METHOD = "x-is-delete-method";
    public static final String X_IS_GET_METHOD = "x-is-get-method";
    public static final String X_IS_HEAD_METHOD = "x-is-head-method";
    public static final String X_IS_OPTIONS_METHOD = "x-is-options-method";
    public static final String X_IS_PATCH_METHOD = "x-is-patch-method";
    public static final String X_IS_POST_METHOD = "x-is-post-method";
    public static final String X_IS_PUT_METHOD = "x-is-put-method";
    public static final String X_IS_TRACE_METHOD = "x-is-trace-method";

    public static final String X_PARAM_GETTER                   = "x-cg-param-getter";
    public static final String X_PARAM_RAW                      = "x-cg-param-raw";
    public static final String X_PARAM_SETTER                   = "x-cg-param-setter";
    public static final String X_PARAM_SET_NULL                 = "x-cg-param-set-null";
    public static final String X_PARAM_CHECKER                  = "x-cg-param-checker";
    public static final String X_PARAM_IS_REQUIRED              = "x-cg-param-is-required";
    public static final String X_CONST_REF_DATATYPE             = "x-cg-const-ref-data-type";
    public static final String X_IS_ENUM_TYPE                   = "x-cg-is-enum-type";
    public static final String X_IS_STRING_TYPE                 = "x-cg-is-string-type";
    public static final String X_IS_PRIMITIVE_TYPE              = "x-cg-is-primitive-type";
    public static final String X_IS_PRIMITIVE_OR_STRING_TYPE    = "x-cg-is-primitive-or-string-type";
    public static final String X_PRIMITIVE_TYPE                 = "x-cg-primitive-type";
    public static final String X_PRIMITIVE_VALUE_MEMBER         = "x-cg-primitive-value-member";
    public static final String X_GETTER_TYPE                    = "x-cg-getter-type";
    public static final String X_SETTER_TYPE                    = "x-cg-setter-type";
    public static final String X_CLEAR_CONTAINER                = "x-cg-clear-container";
    public static final String X_SET_IN_LIST                    = "x-cg-set-in-list";
    public static final String X_APPEND_TO_LIST                 = "x-cg-append-to-list";
    public static final String X_SET_IN_MAP                     = "x-cg-set-in-map";
    public static final String X_UNSET_FROM_MAP                 = "x-cg-unset-from-map";

    public static final String X_HAS_BINARY_BODY_PARAMETER      = "x-cg-has-binary-body-parameter";
    public static final String X_HAS_BINARY_BODY_RESPONSE       = "x-cg-has-binary-body-response";
    public static final String X_BINARY_BODY_RESPONSE_CODE      = "x-cg-binary-body-response-code";

    public static final String X_HAS_ENUM_PARAMETERS            = "x-cg-has-enum-parameters";
    public static final String X_HAS_ENUM_HEADERS               = "x-cg-has-enum-headers";

    public static final String X_ALL_NOTYPE_RESPONSE_CODE_SWITCH_LABELS = "x-all-notype-response-code-switch-labels";
    public static final String X_ALL_UNIQUE_RESPONSE_TYPES              = "x-all-unique-response-types";
    public static final String X_ALL_UNIQUE_RESPONSE_HEADERS            = "x-all-unique-response-headers";
    public static final String X_MIN_HEADER_NAME_LENGTH                 = "x-min-header-name-length";
    public static final String X_MAX_HEADER_NAME_LENGTH                 = "x-max-header-name-length";
    public static final String X_AUR_DATATYPE                           = "x-aur-datatype";
    public static final String X_AUR_MEMBER                             = "x-aur-member";
    public static final String X_AUR_GETTER                             = "x-aur-getter";
    public static final String X_AUR_CHECKER                            = "x-aur-checker";
    public static final String X_AUR_CODE_SWITCH_LABELS                 = "x-aur-code-switch-labels";
    public static final String X_AUR_RESPONSE_CODES                     = "x-aur-response-codes";
    public static final String X_AUR_HEADER_CODES                       = "x-aur-header-codes";
    public static final String X_AUR_RESPONSE                           = "x-aur-response";
    public static final String X_AUR_HEADER                             = "x-aur-header";
    public static final String X_AUR_MATCH_WORD_PARAMS                  = "x-aur-match-word-params";
    public static final String X_AUR_PREPPED_MEMBER                     = "x-aur-prepped-member";
    public static final String X_AUR_PREPPED_SETTER                     = "x-aur-prepped-setter";

    public static final String X_CONSUMES_JSON              = "x-consumes-json";
    public static final String X_HAS_RESPONSE_HEADERS       = "x-has-response-headers";

    public static final String X_RESPONSE_CODE_SWITCH_LABEL = "x-response-code-switch-label";

    public static final String X_MODEL_PRIMITIVE_BASE       = "x-model-primitive-base";
    public static final String X_MODEL_BASE_CLASS           = "x-cg-model-base-class";
    public static final String X_IS_POLYMORPHIC             = "x-cg-is-polymorphic";
    public static final String X_MODEL_DISCRIMINATOR_VALUE  = "x-cg-model-discriminator-value";

    public static final String X_OCI_REQ_SIGN               = "x-cg-oci-req-sign";
    public static final String X_OCI_REQ_SIGN_EXCLUDE_BODY  = "x-cg-oci-req-sign-exclude-body";
    /** @} */

    /** @todo x-obmcs-signing-strategy */
    /** @todo x-obmcs-resolve-component-ref? Only used with 'launchMode'.  Do we care? */
    /** @todo x-obmcs-preview-only? Probably not relevant, unless we want to drop preview operations. */
    /** @todo x-obmcs-feature-id?   Probably not relevant. */

    /** Type mapping for primitive types. */
    protected Map<String, String> primitiveTypeMapping = new HashMap<String, String>();
    /** Value member name for primitive types. */
    protected Map<String, String> primitiveTypeValueMemberMapping = new HashMap<String, String>();

    static Logger LOGGER = LoggerFactory.getLogger(IprtClientCodegen.class);

    @Override
    public CodegenType getTag()
    {
        return CodegenType.CLIENT;
    }

    @Override
    public String getName()
    {
        return "iprt";
    }

    @Override
    public String getHelp()
    {
        return "Generates a IPRT client.";
    }

    public IprtClientCodegen()
    {
        super();

        supportsInheritance = true;

        outputFolder = "generated-code" + File.separator + "iprt";

        apiPackage          = File.separator + "api";
        modelPackage        = File.separator + "model";

        /* Note! To avoid rebuilding when hacking templates try the following to override 'templateDir' default:
                --additional-properties templateDir=/mnt/trunk/src/VBox/Runtime/tools/swagger-codegen/resources/iprt-client */
        templateDir         = "iprt-client";
        embeddedTemplateDir = templateDir;

        /* Model and API file templates: */
        modelTemplateFiles.put("model-header.mustache", ".h");
        modelTemplateFiles.put("model-source.mustache", ".cpp");

        apiTemplateFiles.put("api-header.mustache", ".h");
        apiTemplateFiles.put("api-source.mustache", ".cpp");
        apiTemplateFiles.put("api-request-source.mustache", "-requests.cpp");
        apiTemplateFiles.put("api-response-source.mustache", "-responses.cpp");

        /* Additional template files: */
        supportingFiles.add(new SupportingFile("Makefile-kmk.mustache", "Makefile.kmk"));
        supportingFiles.add(new SupportingFile("Makefile-kup.mustache", "api", "Makefile.kup"));
        supportingFiles.add(new SupportingFile("Makefile-kup.mustache", "model", "Makefile.kup"));


        /*
         * Type mappings.
         *
         *
         * Remarks on the 'object' type:
         *
         * Most model data types "inherits" from the 'object' type.  Fortunately
         * this does not trickle thru to our generated C++ code, so what 'object'
         * is actually mapped to doesn't matter here.
         *
         * Sometimes a model is just string or some other primitive type with
         * added restrctions.  We don't currently map these restrictions and
         * instead typedef the model data type to the primitive type.
         *
         * A spot of trouble arrises when the API spec uses 'object' to say that
         * anything goes.  Now, to come up with something useful with our C++
         * model, we need special chameleon class that can store any other
         * primitive type inside itself.  This is RTCRestAnyObject.
         */
        super.typeMapping = new HashMap<String, String>();
        typeMapping.put("array",            "RTCRestArray");
        typeMapping.put("map",              "RTCRestStringMap");
        typeMapping.put("List",             "RTCRestArray");
        typeMapping.put("boolean",          "RTCRestBool");
        typeMapping.put("string",           "RTCRestString");
        typeMapping.put("int",              "RTCRestInt32");
        typeMapping.put("float",            "RTCRestDouble");
        typeMapping.put("number",           "RTCRestDouble");
        typeMapping.put("DateTime",         "RTCRestDate");
        typeMapping.put("Date",             "RTCRestDate");
        typeMapping.put("date",             "RTCRestDate");
        typeMapping.put("long",             "RTCRestInt64");
        typeMapping.put("short",            "RTCRestInt16");
        typeMapping.put("char",             "RTCRestString");
        typeMapping.put("double",           "RTCRestDouble");
        typeMapping.put("object",           "RTCRestAnyObject"); /* Note! see above. */
        typeMapping.put("integer",          "RTCRestInt32");
        typeMapping.put("ByteArray",        "RTCRestBinary");
        typeMapping.put("binary",           "RTCRestBinary");
        typeMapping.put("file",             "RTCRestBinary");
        typeMapping.put("UUID",             "RTCRestUuid");

        languageSpecificPrimitives = new HashSet<String>(
            Arrays.asList("RTCRestBool", "RTCRestInt16", "RTCRestInt32", "RTCRestInt64", "RTCRestDouble")
        );

        //primitiveTypeMapping = new HashMap<String, String>();
        primitiveTypeMapping.put("RTCRestBool",      "bool");
        primitiveTypeMapping.put("RTCRestInt16",     "int16_t");
        primitiveTypeMapping.put("RTCRestInt32",     "int32_t");
        primitiveTypeMapping.put("RTCRestInt64",     "int64_t");
        primitiveTypeMapping.put("RTCRestDouble",    "double");

        //primitiveTypeValueMemberMapping = new HashMap<String, String>();
        primitiveTypeValueMemberMapping.put("RTCRestBool",      "m_fValue");
        primitiveTypeValueMemberMapping.put("RTCRestInt16",     "m_iValue");
        primitiveTypeValueMemberMapping.put("RTCRestInt32",     "m_iValue");
        primitiveTypeValueMemberMapping.put("RTCRestInt64",     "m_iValue");
        primitiveTypeValueMemberMapping.put("RTCRestDouble",    "m_rdValue");


        /* Native type to include mappings. */
        super.importMapping = new HashMap<String, String>();
        importMapping.put("RTCRestBool",            null);
        importMapping.put("RTCRestInt16",           null);
        importMapping.put("RTCRestInt32",           null);
        importMapping.put("RTCRestInt64",           null);
        importMapping.put("RTCRestDouble",          null);
        importMapping.put("RTCRestString",          null);
        importMapping.put("RTCRestDate",            null);
        importMapping.put("RTCRestUuid",            null);
        importMapping.put("RTCRestArray",           "#include <iprt/cpp/restarray.h>");
        importMapping.put("RTCRestStringMap",       "#include <iprt/cpp/reststringmap.h>");
        importMapping.put("RTCRestAnyObject",       "#include <iprt/cpp/restanyobject.h>");
        importMapping.put("RTCRestBinary",          null);
        importMapping.put("RTCRestBinaryResponse",  null);
        importMapping.put("RTCRestBinaryParameter", null);

        /* CLI option definitions and defaults: */
        addOption(CPP_NAMESPACE, CPP_NAMESPACE_DESC, m_cppNamespace);
        additionalProperties().put(CPP_NAMESPACE, m_cppNamespace);

        addOption(KMK_DEPTH, KMK_DEPTH_DESC, m_kmkDepth);
        additionalProperties().put(KMK_DEPTH, m_kmkDepth);

        addOption(KMK_TARGET, KMK_TARGET_DESC, m_kmkTarget);
        additionalProperties().put(KMK_TARGET, m_kmkTarget);

        addOption(KMK_TEMPLATE, KMK_TEMPLATE_DESC, m_kmkTemplate);
        additionalProperties().put(KMK_TEMPLATE, m_kmkTemplate);

        addSwitch(OCI_REQ_SIGN, OCI_REQ_SIGN_DESC, m_fOciReqSign);

        addOption(COPYRIGHT_STATEMENT, COPYRIGHT_STATEMENT_DESC);
        for (int i = 0; i < 10; i++)
            addOption(COPYRIGHT_LINE + i, COPYRIGHT_LINE_DESC + i);

        /* Additional properties for use in the templates: */
        additionalProperties().put("prefix", PREFIX);  /** @todo do we need/want this? */
    }

    /**
     * Add options via --additional-properties.
     */
    @Override
    public void processOpts()
    {
        super.processOpts();

        if (additionalProperties.containsKey(OCI_REQ_SIGN))
            m_fOciReqSign = true;

        /* Turn --additional-properties cppNamespace=namespace[::namespace[..]] into cppNamespaceDeclarations. */
        if (additionalProperties.containsKey(CPP_NAMESPACE))
            m_cppNamespace = (String)additionalProperties.get(CPP_NAMESPACE);
        additionalProperties.put(CPP_NAMESPACE_DECLS, m_cppNamespace.split("::"));
    }

    /**
     * Override the JMustache compiler configuration to avoid
     * getting the HTML escape treatment (fun for templates).
     *
     * @todo WTF do we need to do this?
     *       Update: Because {{var}} is repalaced by the HTML escaped value,
     *               and {{{var}}} is the raw unescaped value. My bad.
     */
    @Override
    public Compiler processCompiler(Compiler compiler)
    {
        compiler = super.processCompiler(compiler).emptyStringIsFalse(true);
        return compiler.withEscaper(Escapers.NONE);
    }

    @Override
    public String toModelImport(String name)
    {
        if (name.startsWith("#include")) /* WTF? */
            return name;
        if (importMapping.containsKey(name))
            return importMapping.get(name);
        if (name.endsWith("Enum"))
            return null;
        return "#include \"../model/" + toModelFilename(name) + ".h\"";
    }

    @Override
    public String toModelFilename(String name)
    {
        return initialCaps(name);
    }

    @Override
    public String toApiImport(String name)
    {
        if (importMapping.containsKey(name))
            return importMapping.get(name);
        if (name.startsWith("#include")) /* WTF? */
            return name;
        return "#include \"../api/" + toApiFilename(name) + ".h\"";
    }

    @Override
    public String toApiFilename(String name)
    {
        return initialCaps(name) + "Api";
    }

    /** Overriding this to deal wtih arrays, lists and maps. */
    @Override
    public String getTypeDeclaration(Property p)
    {
        String type = getSwaggerType(p);
        //LOGGER.info("iprt/getTypeDeclaration: p=" + p + " type=" + type);
        if (p instanceof ArrayProperty)
        {
            /* type is 'RTCRestArray' */
            ArrayProperty ap = (ArrayProperty)p;
            Property itemType = ap.getItems();
            return type + "< " + getTypeDeclaration(itemType) + " >";
        }
        if (p instanceof MapProperty)
        {
            /* type is 'RTCRestStringMap' */
            MapProperty mp = (MapProperty)p;
            Property itemType = mp.getAdditionalProperties();
            return type + "< " + getTypeDeclaration(itemType) + " >";
        }
        return toModelName(type);
    }

    @Override
    public String getSwaggerType(Property p)
    {
        /* Stupid workaround: Super method doesn't handle '#/responses/Stuff' only '#/definitions/Stuff' */
        if (p instanceof RefProperty)
        {
            RefProperty rp = (RefProperty)p;
            String refType = rp.get$ref();
            if (refType.startsWith("#"))
            {
                String type = null;
                if (refType.startsWith("#/definitions/"))
                    type = refType.substring("#/definitions/".length());
                else if (refType.startsWith("#/responses/"))
                    type = refType.substring("#/responses/".length());
                else
                    assert false;
                if (type != null)
                {
                    String retType = toModelName(type);
                    //LOGGER.info("iprt/getSwaggerType: p=" + p + " refType=" + refType + " type=" + type + " -> " + retType);
                    return retType;
                }
            }
        }

        String type = super.getSwaggerType(p);
        //LOGGER.info("iprt/getSwaggerType: p=" + p + " type=" + type);
        if (typeMapping.containsKey(type))
        {
            type = typeMapping.get(type);
            if (languageSpecificPrimitives.contains(type))
                return type;
        }
        return toModelName(type);
    }

    /** Capitalize model names. */
    @Override
    public String toModelName(String type)
    {
        //LOGGER.info("iprt/toModelName: type=" + type);
        if (   typeMapping.keySet().contains(type)
            || typeMapping.values().contains(type)
            || importMapping.values().contains(type)
            || defaultIncludes.contains(type)
            || languageSpecificPrimitives.contains(type))
            return type;
        return StringUtils.capitalize(type);
    }

    /** Postfix API classes with 'Api'. */
    @Override
    public String toApiName(String type)
    {
        return StringUtils.capitalize(type) + "Api";
    }

    /**
     * Note! This is called at the end of super.fromParameter.
     */
    @Override
    public void postProcessParameter(CodegenParameter parameter)
    {
        super.postProcessParameter(parameter);
        //LOGGER.info("iprt/postProcessParameter: parameter=" + parameter);

        /*
         * First, workaround duplicate item type nesting bug.  This happens
         * with CreateUsersWithArrayInput.
         */
        if (   parameter.items != null
            && parameter.items.items != null
            && parameter.dataType.equals(parameter.items.datatype))
        {
            LOGGER.warn("Applied duplicate item type nesting workaround to '" + parameter.baseName + " (type " + parameter.dataType + ")");
            parameter.items = parameter.items.items;
        }

        /*
         * Specialize the binary parameter type.
         */
        if (   parameter.baseType != null
            && parameter.baseType.equals("RTCRestBinary"))
        {
            parameter.baseType = "RTCRestBinaryParameter";
            if (parameter.dataType.equals("RTCRestBinary"))
                parameter.dataType = "RTCRestBinaryParameter";
            else
                parameter.dataType = parameter.dataType.replace("RTCRestBinary", "RTCRestBinaryParameter");
        }

        /*
         * Extensions to ease code generation.
         */

        /* Add vendorExtensions.x-cg-param-getter and vendor Extensions.x-cg-param-setter for the request object. */
        parameter.vendorExtensions.put(X_PARAM_GETTER,      "get" + StringUtils.capitalize(parameter.paramName));
        parameter.vendorExtensions.put(X_PARAM_RAW,         "raw" + StringUtils.capitalize(parameter.paramName));
        parameter.vendorExtensions.put(X_PARAM_SETTER,      "set" + StringUtils.capitalize(parameter.paramName));
        parameter.vendorExtensions.put(X_PARAM_SET_NULL,    "set" + StringUtils.capitalize(parameter.paramName) + "Null");
        parameter.vendorExtensions.put(X_PARAM_CHECKER,     "has" + StringUtils.capitalize(parameter.paramName));
        parameter.vendorExtensions.put(X_PARAM_IS_REQUIRED, "is" + StringUtils.capitalize(parameter.paramName) + "Required");

        /* Container access methods. */
        if (parameter.isContainer)
        {
            parameter.vendorExtensions.put(X_CLEAR_CONTAINER,       "clear" + StringUtils.capitalize(parameter.paramName));
            if (parameter.isListContainer)
            {
                parameter.vendorExtensions.put(X_SET_IN_LIST,       "setIn" + StringUtils.capitalize(parameter.paramName));
                parameter.vendorExtensions.put(X_APPEND_TO_LIST,    "appendTo" + StringUtils.capitalize(parameter.paramName));
            }
            else
            {
                parameter.vendorExtensions.put(X_SET_IN_MAP,        "setIn" + StringUtils.capitalize(parameter.paramName));
                parameter.vendorExtensions.put(X_UNSET_FROM_MAP,    "unsetFrom" + StringUtils.capitalize(parameter.paramName));
            }
        }

        /* Add vendorExtensions.x-cg-const-ref-data-type for input parameters for setters and return values for getters. */
        if (!parameter.isContainer && parameter.dataType.equals("RTCRestString"))
            parameter.vendorExtensions.put(X_CONST_REF_DATATYPE, "RTCString const &");
        else if (!parameter.isContainer && parameter.isPrimitiveType && primitiveTypeMapping.containsKey(parameter.dataType))
            parameter.vendorExtensions.put(X_CONST_REF_DATATYPE, primitiveTypeMapping.get(parameter.dataType) + " ");
        else
            parameter.vendorExtensions.put(X_CONST_REF_DATATYPE, parameter.dataType + " const &");

        /* For providing overloaded C-string setters.  */
        parameter.vendorExtensions.put(X_IS_STRING_TYPE, parameter.dataType.equals("RTCRestString"));

        /* For simplifying primitive type accesses. */
        if (parameter.isPrimitiveType && !parameter.isContainer)
            parameter.vendorExtensions.put(X_IS_PRIMITIVE_TYPE, "true");

        /* For simplifying primitive & string type accesses. */
        if ((parameter.isPrimitiveType || parameter.dataType.equals("RTCRestString")) && !parameter.isContainer)
            parameter.vendorExtensions.put(X_IS_PRIMITIVE_OR_STRING_TYPE, "true");

        /* For using native primitive types in accesssors. */
        if (   parameter.isPrimitiveType
            && primitiveTypeMapping.containsKey(parameter.dataType))
        {
            parameter.vendorExtensions.put(X_PRIMITIVE_TYPE, primitiveTypeMapping.get(parameter.dataType));
            parameter.vendorExtensions.put(X_PRIMITIVE_VALUE_MEMBER, primitiveTypeValueMemberMapping.get(parameter.dataType));
        }
    }

    @Override
    public String toDefaultValue(Property p)
    {
        //LOGGER.info("iprt/toDefaultValue: p=" + p + " " + Json.pretty(p));
        if (p instanceof StringProperty)
            return "\"\"";
        if (p instanceof BooleanProperty)
            return "false";
        if (p instanceof DateTimeProperty || p instanceof DateProperty)
            return "";
        if (p instanceof DoubleProperty || p instanceof FloatProperty || p instanceof DecimalProperty)
            return "0.0";
        if (p instanceof LongProperty || p instanceof IntegerProperty || p instanceof BaseIntegerProperty)
            return "0";

        if (p instanceof MapProperty)
        {
            MapProperty ap = (MapProperty)p;
            String itemType = getSwaggerType(ap.getAdditionalProperties());
            return "RTCRestStringMap< " + itemType + " >()";
        }
        if (p instanceof ArrayProperty)
        {
            ArrayProperty ap = (ArrayProperty) p;
            String itemType = getSwaggerType(ap.getItems());
            //if (!languageSpecificPrimitives.contains(itemType))
            //    itemType = "<" + itemType + ">"; -- fixme
            return "RTCRestArray< " + itemType + " >()";
        }
        // the rest is, hmm, ...
        if (p instanceof RefProperty)
        {
            RefProperty rp = (RefProperty)p;
            return toModelName(rp.getSimpleRef()) + "()";
        }
        return "0"; // ???
    }

    @Override
    public String escapeQuotationMark(String input)
    {
        /* Remove " to avoid code injection. */
        return input.replace("\"", "");
    }

    @Override
    public String escapeUnsafeCharacters(String input)
    {
        return input.replace("*/", "*_/").replace("/*", "/_*");
    }

    @Override
    public String escapeReservedWord(String name)
    {
        return "_" + name; /* prefix variable with underscore */
    }

    @Override
    public String escapeText(String string)
    {
        if (string != null)
        {
            /* Actually *remove* trailing tabs, newlines and returns: */
            int cch = string.length();
            while (   cch > 0
                   && "\t\n\r".contains(string.substring(cch - 1, cch)))
                cch--;
            if (cch != string.length())
                string = string.substring(0, cch);
        }
        return super.escapeText(string);
    }


    /**
     * We never use the variable name directly (in a model class), it's always
     * prefixed with 'm_', 'k', 'get', 'set' or something, so just sanitize it
     * and return.
     */
    @Override
    public String toVarName(String name)
    {
        if (name.length() > 1)
            return camelize(sanitizeName(Character.toUpperCase(name.charAt(0)) + name.substring(1)));
        return sanitizeName(name);
    }

    /**
     * We never use the variable name directly (in a model class), it's always
     * prefixed with 'm_', 'a_', 'k', 'get', 'set' or something, so just
     * sanitize it and return.
     */
    @Override
    public String toParamName(String name)
    {
        return camelize(removeNonNameElementToCamelCase(name));
    }


    /** Remove the '-*' or '*' suffix of a x-obmcs-header-collection property name. */
    private String cleanupHeaderCollectionName(String name)
    {
        if (name.endsWith("-*"))
            return name.substring(0, name.length() - 2);
        if (name.endsWith("*"))
            return name.substring(0, name.length() - 1);
        return name;
    }

    /**
     * Adds some vendor extensions.
     *
     * - Adds X_IS_STRING_TYPE so we can provide overloaded model setter.
     * - Adds X_IS_PRIMITIVE_TYPE for ANDing 'isNotContainer' and 'isPrimary'.
     * - Adds X_PRIMITIVE_TYPE for int16_t, int32_t, int64_t and double.
     *
     */
    @Override
    public CodegenProperty fromProperty(String name, Property p)
    {
        //LOGGER.info("iprt/fromProperty: name=" + name + " p=" + p);

        /*
         * x-obmcs-header-collection: Requires string -> map<string> transformation.
         */
        String baseName = null;
        if (p != null)
        {
            Map<String,Object> mapVendorExtensions = p.getVendorExtensions();
            if (   mapVendorExtensions != null
                && mapVendorExtensions.containsKey("x-obmcs-header-collection")
                && mapVendorExtensions.containsKey("x-obmcs-prefix"))
            {
                baseName = (String)mapVendorExtensions.get("x-obmcs-prefix");
                LOGGER.info("Applying x-obmcs-prefix to " + name + " (prefix: " + baseName + ")");

                MapProperty mapProp = new MapProperty(p);
                if (p.getName() != null)
                    mapProp.setName(cleanupHeaderCollectionName(p.getName()));
                mapProp.setType("map");
                mapProp.setXml(p.getXml());
                mapProp.setRequired(p.getRequired());
                mapProp.setReadOnly(p.getReadOnly());
                mapProp.setTitle(p.getTitle());
                mapProp.setDescription(p.getDescription());
                for (Map.Entry<String, Object> entry : mapVendorExtensions.entrySet())
                    mapProp.vendorExtension(entry.getKey(), entry.getValue());

                mapVendorExtensions.remove("x-obmcs-header-collection");
                mapVendorExtensions.remove("x-obmcs-prefix");

                p = mapProp;
                name = cleanupHeaderCollectionName(name);
            }
        }

        /*
         * Call super.
         */
        CodegenProperty codegenProperty = super.fromProperty(name, p);

        if (codegenProperty != null)
            codegenProperty = updateVendorExtensions(codegenProperty, name, baseName);

        return codegenProperty;
    }

    private CodegenProperty updateVendorExtensions( CodegenProperty cp, String name, String baseName )
    {
        CodegenProperty codegenProperty = cp;

        if (codegenProperty != null)
        {
            if (codegenProperty.items != null && codegenProperty.isContainer)
                codegenProperty.items = updateVendorExtensions(codegenProperty.items, name, baseName);

            /* Make sure the vendor extensions are unique. */
            codegenProperty.vendorExtensions = copyVendorExtensions(codegenProperty.vendorExtensions, "fromProperty");

            /* Preserve header wildcard name. */
            if (baseName != null)
                codegenProperty.baseName = baseName;

            /*
             * Correct enum data type.  For operations, we'll qualifying it later in the process.
             */
            if (codegenProperty.isEnum)
            {
                if (!codegenProperty.isContainer)
                {
                    codegenProperty.datatype = codegenProperty.enumName;
                    codegenProperty.vendorExtensions.put(X_IS_ENUM_TYPE, "true");
                }
                else
                {
                    assert codegenProperty.items != null;
                    assert codegenProperty.isEnum;
                    assert !codegenProperty.items.isContainer;
                    if (!codegenProperty.items.datatype.equals(codegenProperty.items.enumName))
                        codegenProperty.items.datatype = codegenProperty.items.enumName;
                    if (codegenProperty.isMapContainer)
                        codegenProperty.datatype = "RTCRestStringMap< " + codegenProperty.items.datatype + " >";
                    else
                        codegenProperty.datatype = "RTCRestArray< " + codegenProperty.items.datatype + " >";
                }
            }

            /*
             * Add what we need to the vendor extension map.
             */
            codegenProperty.vendorExtensions.put(X_IS_STRING_TYPE, codegenProperty.datatype.equals("RTCRestString"));

            if (   codegenProperty.isPrimitiveType
                && primitiveTypeMapping.containsKey(codegenProperty.datatype))
            {
                codegenProperty.vendorExtensions.put(X_PRIMITIVE_TYPE, primitiveTypeMapping.get(codegenProperty.datatype));
                codegenProperty.vendorExtensions.put(X_PRIMITIVE_VALUE_MEMBER,
                                                     primitiveTypeValueMemberMapping.get(codegenProperty.datatype));
            }

            if (codegenProperty.isPrimitiveType && !codegenProperty.isContainer)
                codegenProperty.vendorExtensions.put(X_IS_PRIMITIVE_TYPE, "true");

            if (   (codegenProperty.isPrimitiveType || codegenProperty.datatype.equals("RTCRestString"))
                && !codegenProperty.isContainer)
                codegenProperty.vendorExtensions.put(X_IS_PRIMITIVE_OR_STRING_TYPE, "true");

            if (codegenProperty.isContainer)
            {
                String strCapName = StringUtils.capitalize(codegenProperty.name);
                codegenProperty.vendorExtensions.put(X_CLEAR_CONTAINER, "clear" + strCapName);
                if (codegenProperty.isListContainer)
                {
                    codegenProperty.vendorExtensions.put(X_SET_IN_LIST,    "setIn" + strCapName);
                    codegenProperty.vendorExtensions.put(X_APPEND_TO_LIST, "appendTo" + strCapName);
                }
                else
                {
                    codegenProperty.vendorExtensions.put(X_SET_IN_MAP,     "setIn" + strCapName);
                    codegenProperty.vendorExtensions.put(X_UNSET_FROM_MAP, "unsetFrom" + strCapName);
                }
            }

            if (!codegenProperty.isContainer && codegenProperty.datatype.equals("RTCRestString"))
                codegenProperty.vendorExtensions.put(X_CONST_REF_DATATYPE, "RTCString const &");
            else if (   !codegenProperty.isContainer
                     && codegenProperty.isPrimitiveType
                     && primitiveTypeMapping.containsKey(codegenProperty.datatype))
                codegenProperty.vendorExtensions.put(X_CONST_REF_DATATYPE, primitiveTypeMapping.get(codegenProperty.datatype) + " ");
            else
                codegenProperty.vendorExtensions.put(X_CONST_REF_DATATYPE, codegenProperty.datatype + " const &");
        }
        return codegenProperty;
    }

    @Override
    public CodegenModel fromModel(String name, Model model, Map<String, Model> allDefinitions)
    {
        //LOGGER.info("iprt/fromModel: name=" + name + " model=" + model);
        assert !(model instanceof RefModel);

        CodegenModel codegenModel = super.fromModel(name, model, allDefinitions);

        /* Make sure the vendor extensions are unique. */
        codegenModel.vendorExtensions = copyVendorExtensions(codegenModel.vendorExtensions, "fromModel");

        /*
         * Apply imports to toModelImport() and skip duplicates.
         */
        Set<String> oldImports = codegenModel.imports;
        codegenModel.imports = new HashSet<String>();
        for (String imp : oldImports)
        {
            String newImp = toModelImport(imp);
            if (newImp != null && !newImp.isEmpty() && !codegenModel.imports.contains(newImp))
                codegenModel.imports.add(newImp);
        }

        /*
         * Base class hacks.  We need to translate RTCRestAnyObject to RTCRestDataObject,
         * see notes on super.typeMapping in the constructor.  x-cg-model-base-class is
         * added for convenience and X_MODEL_PRIMITIVE_BASE as an ugly temporary hack.
         *
         * Note! postProcessModels does more work on inheritance.
         */
        if (codegenModel.dataType == null)
            codegenModel.vendorExtensions.put(X_MODEL_BASE_CLASS,
                                              codegenModel.parent == null ? "RTCRestDataObject" : codegenModel.parent);
        else if (codegenModel.dataType.equals("RTCRestAnyObject"))
        {
            /* We get here when someone uses 'type: object' on the model definition (e.g. DhcpOption). */
            codegenModel.dataType = null;
            codegenModel.vendorExtensions.put(X_MODEL_BASE_CLASS,
                                              codegenModel.parent == null ? "RTCRestDataObject" : codegenModel.parent);
        }
        else if (   codegenModel.dataType.equals("RTCRestString")
                 || codegenModel.dataType.equals("RTCRestInt64")
                 || codegenModel.dataType.equals("RTCRestInt32")
                 || codegenModel.dataType.equals("RTCRestInt16")
                 || codegenModel.dataType.equals("RTCRestDouble")
                 || codegenModel.dataType.equals("RTCRestBool")
                 || codegenModel.dataType.equals("RTCRestBinaryParameter")
                 || codegenModel.dataType.equals("RTCRestBinaryResponse") )
        {
            codegenModel.vendorExtensions.put(X_MODEL_PRIMITIVE_BASE, codegenModel.dataType);
            codegenModel.vendorExtensions.put(X_MODEL_BASE_CLASS, codegenModel.dataType);
        }
        else
        {
            LOGGER.warn("Data class '" + codegenModel.name + "' has invalid base type: " + codegenModel.dataType);
            codegenModel.vendorExtensions.put(X_MODEL_PRIMITIVE_BASE, codegenModel.dataType);
            codegenModel.vendorExtensions.put(X_MODEL_BASE_CLASS, codegenModel.dataType);
        }

        /*
         * Qualify enum data types.
         */
        String classPrefix = codegenModel.classname + "::";
        for (CodegenProperty codegenProp : codegenModel.vars)
            if (codegenProp.isEnum)
                qualifyPropertyEnum(classPrefix, codegenProp, false /*fIsHeader*/);

        return codegenModel;
    }

    /**
     * This seems to be required for enum support.
     * (This is called for each model, it seems.)
     */
    @Override
    public Map<String, Object> postProcessModels(Map<String, Object> objs)
    {
        //LOGGER.info("iprt/postProcessModels: objs=" + objs);
        return postProcessModelsEnum(/*super.postProcessModels(objs)*/ objs);
    }

    /**
     * Gets the discriminator value for the given child model.
     */
    private String getDiscriminatorValue(CodegenModel codegenModel)
    {
        /* HACK ALERT! The OpenAPI 2.0 does not define how to do this.  The specs we
                       are working with are reusing the 'discriminator' in children
                       to set the value. */
        if (codegenModel.parent != null && codegenModel.children == null)
            return codegenModel.discriminator;
        assert codegenModel.parent != null;
        assert codegenModel.children == null;
        return "RTCRestError<missing_discriminator_value>";
    }

    /** Turns strValue into a constant value for the given type. */
    private String escapePropValueAsNeeded(CodegenProperty codegenProp, String strValue)
    {
        /* This isn't perfect! */
        if (codegenProp.isString)
        {
            if (strValue.startsWith("\"") && strValue.endsWith("\""))
                return strValue;
            return "\"" + escapeQuotationMark(strValue) + "\"";
        }
        return strValue;
    }

    /** Worker for setDiscriminatorValue. */
    private void setDiscriminatorValueOnPropList(List<CodegenProperty> propList, String strDiscriminator, String strValue)
    {
        for (CodegenProperty codegenProp : propList)
            if (codegenProp.discriminatorValue == null && codegenProp.baseName.equals(strDiscriminator))
                codegenProp.discriminatorValue = strValue;
    }

    /**
     * Sets the decriminator value for children.
     */
    private void setDiscriminatorValue(CodegenModel codegenModel, String strDiscriminator, String strValue)
    {
        if (strValue != null)
        {
            /* simplification: */
            boolean fFound = false;
            for (CodegenProperty codegenProp : codegenModel.allVars)
                if (codegenProp.baseName.equals(strDiscriminator))
                {
                    strValue = escapePropValueAsNeeded(codegenProp, strValue);
                    fFound = true;
                    break;
                }
            assert fFound;
            codegenModel.vendorExtensions.put(X_MODEL_DISCRIMINATOR_VALUE, strValue);

            /* Set the variable property: */
            setDiscriminatorValueOnPropList(codegenModel.vars,          strDiscriminator, strValue);
            setDiscriminatorValueOnPropList(codegenModel.requiredVars,  strDiscriminator, strValue);
            setDiscriminatorValueOnPropList(codegenModel.optionalVars,  strDiscriminator, strValue);
            setDiscriminatorValueOnPropList(codegenModel.readOnlyVars,  strDiscriminator, strValue);
            setDiscriminatorValueOnPropList(codegenModel.readWriteVars, strDiscriminator, strValue);
            setDiscriminatorValueOnPropList(codegenModel.allVars,       strDiscriminator, strValue);
            setDiscriminatorValueOnPropList(codegenModel.parentVars,    strDiscriminator, strValue);

            /* And all descendants: */
            if (codegenModel.children != null)
                for (CodegenModel childModel : codegenModel.children)
                    setDiscriminatorValue(childModel, strDiscriminator, strValue);
        }
    }


    /**
     * Polish inheritance once all models have been processed.
     * (This is called once after all the postProcessModels calls.)
     *
     * Note! CodegenModel.hasChildren is not set by the default codegen.
     */
    @Override
    public Map<String, Object> postProcessAllModels(Map<String, Object> allModels)
    {
        LOGGER.info("iprt/postProcessAllModels:");
        allModels = super.postProcessAllModels(allModels);

        /*
         * Pass one: Set hasChildren; adjust parent base class; reject multilevel inheritance.
         */
        for (Object allObject : allModels.values())
        {
            Map<String, Object>       allMap = (Map<String, Object>)allObject;
            List<Map<String, Object>> models = (List<Map<String, Object>>)allMap.get("models");
            for (Map<String, Object>  modelObject : models)
            {
                CodegenModel codegenModel = (CodegenModel) modelObject.get("model");
                if (codegenModel.children != null && !codegenModel.children.isEmpty())
                    codegenModel.hasChildren = true;

                if (codegenModel.hasChildren)
                {
                    if (codegenModel.parent == null)
                    {
                        String strBaseClass = (String)codegenModel.vendorExtensions.get(X_MODEL_BASE_CLASS);
                        if (strBaseClass.equals("RTCRestDataObject"))
                        {
                             LOGGER.info("iprt/postProcessAllModels: " + codegenModel.name +": setting RTCRestPolyDataObject as base class");
                             codegenModel.vendorExtensions.put(X_MODEL_BASE_CLASS, "RTCRestPolyDataObject");
                        }
                        else
                        {
                            LOGGER.error("Data class '" + codegenModel.name + "' inherits from '" + strBaseClass + "' rather than RTCRestDataObject!");
                            assert strBaseClass.equals("RTCRestDataObject");
                        }
                    }
                    else
                    {
                        LOGGER.error("Data class '" + codegenModel.name + "' has both a parent (" + codegenModel.parent
                                     + ") and children (" + codegenModel.children + ")!");
                        assert codegenModel.parent == null;
                    }
                }
            }
        }

        /*
         * Pass two: Indicate whether model properties (data members) involve polymorphic types.
         *           Also set the discrimatorValue when we can.
         */
        for (Object allObject : allModels.values())
        {
            Map<String, Object>       allMap = (Map<String, Object>)allObject;
            List<Map<String, Object>> models = (List<Map<String, Object>>)allMap.get("models");
            for (Map<String, Object>  modelObject : models)
            {
                CodegenModel codegenModel = (CodegenModel) modelObject.get("model");
                for (CodegenProperty codegenProp : codegenModel.vars)
                {
                    if (   !codegenProp.isContainer
                        && !codegenProp.isPrimitiveType
                        && codegenProp.datatype != null
                        && !codegenProp.datatype.startsWith("RTCRest"))
                    {
                        CodegenModel dataTypeModel = ModelUtils.getModelByName(codegenProp.datatype, allModels);
                        if (   dataTypeModel != null
                            && dataTypeModel.hasChildren)
                        {
                            LOGGER.error("Data class '" + codegenModel.name + "' variable '" + codegenProp.name
                                         + "' (type: " + codegenProp.datatype + ") is polymorphic!");
                            codegenProp.vendorExtensions.put(X_IS_POLYMORPHIC, "true");
                        }
                    }
                }

                if (codegenModel.discriminator != null && codegenModel.children != null)
                    for (CodegenModel childModel : codegenModel.children)
                        setDiscriminatorValue(childModel, codegenModel.discriminator, getDiscriminatorValue(childModel));
            }
        }

        return allModels;
    }

    /** Checks if a given media type is present in the type map. */
    private boolean hasMediaType(List<Map<String, String>> typeMap, String type)
    {
        for( Map<String, String> map : typeMap)
        {
            if (map.containsValue(type))
                return true;
        }
        return false;
    }

    /** Qualifies enum parameters with the given request class name prefix (includes ::). */
    private int qualifyParameterEnum(String requestClassPrefix, CodegenParameter codegenParam)
    {
        if (codegenParam.isEnum && !codegenParam.vendorExtensions.containsKey("x-obmcs-enumref"))
        {
            if (!codegenParam.isContainer)
            {
                if (!codegenParam.dataType.startsWith(requestClassPrefix))
                {
                    codegenParam.dataType = requestClassPrefix + codegenParam.dataType;
                    codegenParam.vendorExtensions.put(X_CONST_REF_DATATYPE, codegenParam.dataType + " const &");
                }
                codegenParam.vendorExtensions.put(X_IS_ENUM_TYPE, "true");
            }
            else
            {
                if (!codegenParam.items.datatype.startsWith(requestClassPrefix))
                {
                    codegenParam.items.datatype = requestClassPrefix + codegenParam.items.datatype;
                    codegenParam.items.vendorExtensions.put(X_CONST_REF_DATATYPE,
                                                            requestClassPrefix + "k" + codegenParam.items.enumName + " ");
                    codegenParam.items.vendorExtensions.put(X_IS_ENUM_TYPE, "true");
                }
                codegenParam.datatypeWithEnum = codegenParam.items.datatype;

                if (codegenParam.isMapContainer)
                    codegenParam.dataType = "RTCRestStringMap< " + codegenParam.items.datatype + " >";
                else
                    codegenParam.dataType = "RTCRestArray< " + codegenParam.items.datatype + " >";
                codegenParam.vendorExtensions.put(X_CONST_REF_DATATYPE, codegenParam.dataType + " const &");
            }
            codegenParam.datatypeWithEnum = codegenParam.dataType;
            return 1;
        }
        return 0;
    }

    /** Qualifies enum property with the given request class name prefix (includes ::). */
    private int qualifyPropertyEnum(String classPrefix, CodegenProperty codegenProp, boolean fIsHeader)
    {
        if (codegenProp.isEnum && !codegenProp.vendorExtensions.containsKey("x-obmcs-enumref"))
        {
            if (!codegenProp.isContainer)
            {
                if (!codegenProp.datatype.startsWith(classPrefix))
                {
                    codegenProp.datatype = classPrefix + codegenProp.datatype;
                    codegenProp.vendorExtensions.put(X_CONST_REF_DATATYPE, codegenProp.datatype + " const &");
                    codegenProp.vendorExtensions.put(X_IS_ENUM_TYPE, "true");
                    if (fIsHeader)
                        updateCodegenPropertyEnum(codegenProp);
                }
            }
            else
            {
                if (!codegenProp.items.datatype.startsWith(classPrefix))
                {
                    codegenProp.items.datatype = classPrefix + codegenProp.items.datatype;
                    codegenProp.items.vendorExtensions.put(X_CONST_REF_DATATYPE,
                                                             classPrefix + "k" + codegenProp.items.enumName + " ");
                    codegenProp.items.vendorExtensions.put(X_IS_ENUM_TYPE, "true");
                    if (fIsHeader)
                        updateCodegenPropertyEnum(codegenProp);
                }
                codegenProp.datatypeWithEnum = codegenProp.items.datatype;

                if (codegenProp.isMapContainer)
                    codegenProp.datatype = "RTCRestStringMap< " + codegenProp.items.datatype + " >";
                else
                    codegenProp.datatype = "RTCRestArray< " + codegenProp.items.datatype + " >";
                codegenProp.vendorExtensions.put(X_CONST_REF_DATATYPE, codegenProp.datatype + " const &");
            }
            codegenProp.datatypeWithEnum = codegenProp.datatype;
            return 1;
        }
        return 0;
    }

    /**
     * Override fromOperation to add a list of unique response objects.
     */
    @Override
    public CodegenOperation fromOperation(String path,
                                          String httpMethod,
                                          Operation operation,
                                          Map<String, Model> definitions,
                                          Swagger swagger)
    {
        //LOGGER.info("iprt/fromOperation: path=" + path + " httpMethod=" + httpMethod + " operation=" + operation);
        CodegenOperation codegenOperation = super.fromOperation(path, httpMethod, operation, definitions, swagger);
        //LOGGER.info("iprt/fromOperation: codegenOperation=" + codegenOperation.nickname);

        /* Just in case, make sure the vendor extensions are unique. */
        codegenOperation.vendorExtensions = copyVendorExtensions(codegenOperation.vendorExtensions, "fromOperation");

        /*
         * DefaultCodegen used to have this but it was disabled along
         * with some other stuff.  Bring this part back.
         */
        if (codegenOperation.httpMethod.equalsIgnoreCase("DELETE"))
            codegenOperation.vendorExtensions.put(X_IS_DELETE_METHOD, Boolean.TRUE);
        else if (codegenOperation.httpMethod.equalsIgnoreCase("GET"))
            codegenOperation.vendorExtensions.put(X_IS_GET_METHOD, Boolean.TRUE);
        else if (codegenOperation.httpMethod.equalsIgnoreCase("HEAD"))
            codegenOperation.vendorExtensions.put(X_IS_HEAD_METHOD, Boolean.TRUE);
        else if (codegenOperation.httpMethod.equalsIgnoreCase("OPTIONS"))
            codegenOperation.vendorExtensions.put(X_IS_OPTIONS_METHOD, Boolean.TRUE);
        else if (codegenOperation.httpMethod.equalsIgnoreCase("PATCH"))
            codegenOperation.vendorExtensions.put(X_IS_PATCH_METHOD, Boolean.TRUE);
        else if (codegenOperation.httpMethod.equalsIgnoreCase("POST"))
            codegenOperation.vendorExtensions.put(X_IS_POST_METHOD, Boolean.TRUE);
        else if (codegenOperation.httpMethod.equalsIgnoreCase("PUT"))
            codegenOperation.vendorExtensions.put(X_IS_PUT_METHOD, Boolean.TRUE);
        else if (codegenOperation.httpMethod.equalsIgnoreCase("TRACE"))
            codegenOperation.vendorExtensions.put(X_IS_TRACE_METHOD, Boolean.TRUE);


        /*
         * Qualify parameter enums.
         */
        assert codegenOperation.nickname != null;
        String className = codegenOperation.operationIdCamelCase != null
                         ? codegenOperation.operationIdCamelCase
                         : StringUtils.capitalize(codegenOperation.nickname);
        String requestClassPrefix = className + "Request::";
        int cEnums = 0;
        for (CodegenParameter codegenParam : codegenOperation.allParams)
            cEnums += qualifyParameterEnum(requestClassPrefix, codegenParam);
        for (CodegenParameter codegenParam : codegenOperation.bodyParams)
            cEnums += qualifyParameterEnum(requestClassPrefix, codegenParam);
        for (CodegenParameter codegenParam : codegenOperation.pathParams)
            cEnums += qualifyParameterEnum(requestClassPrefix, codegenParam);
        for (CodegenParameter codegenParam : codegenOperation.queryParams)
            cEnums += qualifyParameterEnum(requestClassPrefix, codegenParam);
        for (CodegenParameter codegenParam : codegenOperation.headerParams)
            cEnums += qualifyParameterEnum(requestClassPrefix, codegenParam);
        for (CodegenParameter codegenParam : codegenOperation.formParams)
            cEnums += qualifyParameterEnum(requestClassPrefix, codegenParam);
        for (CodegenParameter codegenParam : codegenOperation.requiredParams)
            cEnums += qualifyParameterEnum(requestClassPrefix, codegenParam);
        if (cEnums > 0)
            codegenOperation.vendorExtensions.put(X_HAS_ENUM_PARAMETERS, "true");

        /*
         * Qualify and correct response header enums.
         */
        cEnums = 0;
        String responseClassPrefix = className + "Response::";
        for (CodegenProperty codegenHeader : codegenOperation.responseHeaders)
            cEnums += qualifyPropertyEnum(responseClassPrefix, codegenHeader, true /*fIsHeader*/);
        for (CodegenResponse codegenResponse : codegenOperation.responses)
            for (CodegenProperty codegenHeader : codegenResponse.headers)
                cEnums += qualifyPropertyEnum(responseClassPrefix, codegenHeader, true /*fIsHeader*/);
        if (cEnums > 0)
            codegenOperation.vendorExtensions.put(X_HAS_ENUM_HEADERS, "true");

        /*
         * Collect unique responses and unique response header fields.
         */
        ArrayList<Map<String, Object>>  responseTypes = new ArrayList<>();
        String                          binaryBodyResponseCode = null;
        boolean                         fHasResponseHeaders = false;
        ArrayList<String>               responseNotypeSwitchLabels = new ArrayList<>();
        ArrayList<String>               uniqueHeaders = new ArrayList<>();
        ArrayList<Map<String, Object>>  headerFields  = new ArrayList<>();
        int                             cchMinHeaderName = 0x7fff;
        int                             cchMaxHeaderName = 0;

        for (CodegenResponse codegenResponse : codegenOperation.responses)
        {
            //LOGGER.info("fromOperation: code=" + codegenResponse.code + " dataType=" + codegenResponse.dataType + " baseType=" + codegenResponse.baseType + " containerType=" + codegenResponse.containerType + " schema=" + codegenResponse.schema + " isString=" + codegenResponse.isString + " primitiveType=" + codegenResponse.primitiveType + " isMapContainer=" + codegenResponse.isMapContainer + " isListContainer=" + codegenResponse.isListContainer);
            assert codegenResponse.dataType == null || !codegenResponse.dataType.startsWith("#");

            /*
             * Determin the switch code label for the response.
             */
            String switchCodeLabel;
            if (   codegenResponse.code.equals("default")
                || codegenResponse.code.equals("0"))
                switchCodeLabel = "default";
            else
                switchCodeLabel = "case " + codegenResponse.code;

            if (codegenResponse.dataType != null)
            {
                /*
                 * Figure base name for the response and set the member name.
                 */
                String name;
                if (codegenResponse.baseType.equals("RTCRestBinaryResponse"))
                    name = "Binary";
                else if (codegenResponse.baseType.startsWith("RTCRest"))
                    name = codegenResponse.baseType.substring(7);
                else
                    name = StringUtils.capitalize(codegenResponse.baseType);

                if (codegenResponse.isListContainer)
                    name = name + "List";
                else if (codegenResponse.isMapContainer)
                    name = name + "Map";

                codegenResponse.vendorExtensions.put(X_AUR_MEMBER, "m_p" + name);

                /*
                 * Collect unique types.
                 */
                boolean fFound = false;
                for (Map<String, Object> map : responseTypes)
                    if (   name.equals(((String)map.get(X_AUR_MEMBER)).substring(3))
                        && codegenResponse.dataType.equals((String)map.get(X_AUR_DATATYPE)))
                    {
                        map.put(X_AUR_RESPONSE_CODES, (String)map.get(X_AUR_RESPONSE_CODES) + ", " + codegenResponse.code);
                        ArrayList<String> switchArray = (ArrayList<String>)map.get(X_AUR_CODE_SWITCH_LABELS);
                        switchArray.add(switchCodeLabel);
                        fFound = true;
                    }
                if (!fFound)
                {
                    /* Create property map for use in the mustache templates and
                       add it to the unique response type array.
                       Note! The X_AUR_RESPONSE makes the entire response available. */
                    Map<String, Object> map = new HashMap<>();
                    map.put(X_AUR_MEMBER,           "m_p" + name);
                    map.put(X_AUR_GETTER,           "get" + name);
                    map.put(X_AUR_CHECKER,          "has" + name);
                    map.put(X_AUR_RESPONSE,         codegenResponse);
                    map.put(X_AUR_DATATYPE,         codegenResponse.dataType);
                    map.put(X_AUR_RESPONSE_CODES,   codegenResponse.code);
                    ArrayList<String> switchArray = new ArrayList<String>();
                    switchArray.add(switchCodeLabel);
                    map.put(X_AUR_CODE_SWITCH_LABELS, switchArray);
                    if (codegenResponse.dataType.equals("RTCRestBinaryResponse"))
                    {
                        map.put(X_AUR_PREPPED_MEMBER, "m_pPrepped" + name);
                        map.put(X_AUR_PREPPED_SETTER, "setPrepped" + name);
                    }

                    responseTypes.add(map);
                }

                /*
                 * Check for binary body responses.
                 */
                if (codegenResponse.dataType.equals("RTCRestBinaryResponse"))
                {
                    if (binaryBodyResponseCode == null)
                        binaryBodyResponseCode = codegenResponse.code;
                    else
                        LOGGER.error("Operation " + codegenOperation.nickname
                                     + " has multiple status codes with binary reponses: " + binaryBodyResponseCode
                                     + ", " + codegenResponse.code);
                }
            }
            else
                responseNotypeSwitchLabels.add(switchCodeLabel);

            /*
             * Response headers.
             */
            if (codegenResponse.hasHeaders)
            {
                fHasResponseHeaders = true;
                for (CodegenProperty codegenHeader : codegenResponse.headers)
                {
                    /* Figure base name. */
                    String name = codegenHeader.name;
                    if (codegenHeader.getter.startsWith("get"))
                        name = codegenHeader.getter.substring(3);

                    /* Combining name and type means we'll end up with compilation
                       errors if the same field is used with different types.  Would
                       need to mangle the name in that case. */
                    String strCombined = name + "::" + codegenHeader.datatype;
                    if (!uniqueHeaders.contains(strCombined))
                    {
                        uniqueHeaders.add(strCombined);

                        /* Create property map for use in the mustache templates and
                           add it to the unique response type array.
                           Note! The X_AUR_HEADER makes the entire header info available. */
                        Map<String, Object> map = new HashMap<>();
                        map.put(X_AUR_MEMBER,       "m_p" + name);
                        map.put(X_AUR_GETTER,       codegenHeader.getter);
                        map.put(X_AUR_CHECKER,      "has" + name);
                        map.put(X_AUR_DATATYPE,     codegenHeader.datatype);
                        map.put(X_AUR_HEADER_CODES, codegenResponse.code);
                        map.put(X_AUR_HEADER,       codegenHeader);
                        String strParams = "" + codegenHeader.baseName.length()
                                         + ", '" + Character.toLowerCase(codegenHeader.baseName.charAt(0)) + "'"
                                         + (  codegenHeader.baseName.length() >= 2
                                            ? ", '" + Character.toLowerCase(codegenHeader.baseName.charAt(1)) + "'" : ", 0")
                                         + (  codegenHeader.baseName.length() >= 3
                                            ? ", '" + Character.toLowerCase(codegenHeader.baseName.charAt(2)) + "'" : ", 0");
                        map.put(X_AUR_MATCH_WORD_PARAMS, strParams);

                        headerFields.add(map);

                        if (   !codegenHeader.vendorExtensions.containsKey("x-obmcs-header-collection")
                            || !codegenHeader.vendorExtensions.containsKey("x-obmcs-prefix"))
                        {
                            int cch = codegenHeader.baseName.length();
                            if (cch > cchMaxHeaderName)
                                cchMaxHeaderName = cch;
                            if (cch < cchMinHeaderName)
                                cchMinHeaderName = cch;
                        }
                        else
                        {
                            cchMaxHeaderName = 0;
                            String strPrefix = (String)codegenHeader.vendorExtensions.get("x-obmcs-prefix");
                            if (strPrefix.length() < cchMinHeaderName)
                                cchMinHeaderName = strPrefix.length();
                        }

                    }
                    else
                        for (Map<String, Object> map : headerFields)
                            if (   name.equals(((String)map.get(X_AUR_MEMBER)).substring(3))
                                && codegenHeader.datatype.equals((String)map.get(X_AUR_DATATYPE)))
                                map.put(X_AUR_HEADER_CODES, (String)map.get(X_AUR_HEADER_CODES) + ", " + codegenResponse.code);
                }
            }
        }
        codegenOperation.vendorExtensions.put(X_ALL_UNIQUE_RESPONSE_TYPES, responseTypes);
        codegenOperation.vendorExtensions.put(X_ALL_NOTYPE_RESPONSE_CODE_SWITCH_LABELS, responseNotypeSwitchLabels);
        if (fHasResponseHeaders)
        {
            codegenOperation.vendorExtensions.put(X_ALL_UNIQUE_RESPONSE_HEADERS, headerFields);
            codegenOperation.vendorExtensions.put(X_HAS_RESPONSE_HEADERS, "true");
        }
        if (uniqueHeaders.size() > 2)
        {
            codegenOperation.vendorExtensions.put(X_MIN_HEADER_NAME_LENGTH, cchMinHeaderName);
            if (cchMaxHeaderName > 0)
                codegenOperation.vendorExtensions.put(X_MAX_HEADER_NAME_LENGTH, cchMaxHeaderName);
        }

        /*
         * Add body format indicator for request and response.
         *
         * Note! For responses, we're kind of assuming a success kind of response code.
         */
        if (   codegenOperation.bodyParams != null
            && !codegenOperation.bodyParams.isEmpty())
        {
            CodegenParameter bodyParam = codegenOperation.bodyParams.get(0);
            assert bodyParam.dataType.equals("RTCRestBinaryParameter")
                || bodyParam.dataFormat == null
                || (!bodyParam.dataFormat.equals("binary") && !bodyParam.dataFormat.equals("file"));
            if (bodyParam.dataType.equals("RTCRestBinaryParameter"))
                codegenOperation.vendorExtensions.put(X_HAS_BINARY_BODY_PARAMETER, "true");
            else
                codegenOperation.vendorExtensions.put(X_CONSUMES_JSON, "true");
        }

        if (binaryBodyResponseCode != null)
        {
            codegenOperation.vendorExtensions.put(X_BINARY_BODY_RESPONSE_CODE, binaryBodyResponseCode);
            codegenOperation.vendorExtensions.put(X_HAS_BINARY_BODY_RESPONSE, "true");
        }

        /*
         * Add OCI request signing indicator.
         */
        if (m_fOciReqSign)
        {
            codegenOperation.vendorExtensions.put(X_OCI_REQ_SIGN, "true");
            if (codegenOperation.vendorExtensions.containsKey("x-obmcs-signing-strategy"))
            {
                String strValue = (String)codegenOperation.vendorExtensions.get("x-obmcs-signing-strategy");
                if (strValue != null && strValue.equals("exclude_body"))
                    codegenOperation.vendorExtensions.put(X_OCI_REQ_SIGN_EXCLUDE_BODY, "true");
                else
                    LOGGER.error("Unsupported x-obmcs-signing-strategy value: " + strValue);
            }
        }

        return codegenOperation;
    }

    /**
     * Override to provide switch labels and alters the binary type.
     */
    @Override
    public CodegenResponse fromResponse(String responseCode, Response response)
    {
        //LOGGER.info("iprt/fromResponse: responseCode=" + responseCode + " response=" + response);
        CodegenResponse codegenResponse = super.fromResponse(responseCode, response);
        //LOGGER.info("iprt/fromResponse: codegenResponse=" + codegenResponse);
        assert codegenResponse.baseType == null || !codegenResponse.baseType.startsWith("#");

        /* Make sure the vendor extensions are unique. */
        codegenResponse.vendorExtensions = copyVendorExtensions(codegenResponse.vendorExtensions, "fromResponse");

        if (   codegenResponse.code.equals("default")
            || codegenResponse.code.equals("0"))
            codegenResponse.vendorExtensions.put(X_RESPONSE_CODE_SWITCH_LABEL, "default");
        else
            codegenResponse.vendorExtensions.put(X_RESPONSE_CODE_SWITCH_LABEL, "case " + codegenResponse.code);

        /* Specialize the binary response type. */
        if (   codegenResponse.baseType != null
            && codegenResponse.baseType.equals("RTCRestBinary"))
        {
            assert codegenResponse.containerType == null;
            assert codegenResponse.dataType.equals(codegenResponse.baseType);
            codegenResponse.baseType = "RTCRestBinaryResponse";
            codegenResponse.dataType = "RTCRestBinaryResponse";
        }
        if (codegenResponse.dataType != null)
            assert codegenResponse.dataType == null || !codegenResponse.dataType.equals("RTCRestBinary");

        return codegenResponse;
    }

    /**
     * Override this to fix up defaultValue.
     */
    @Override
    public CodegenParameter fromParameter(Parameter param, Set<String> imports)
    {
        //LOGGER.info("iprt/fromParameter: param=" + param + " name=" + param.getName());

        /*
         * x-obmcs-header-collection: Make header parameter an object with input as inner type.
         */
        if (   param != null
            && param instanceof HeaderParameter)
        {
            Map<String,Object> mapVendorExtensions = param.getVendorExtensions();
            if (   mapVendorExtensions != null
                && mapVendorExtensions.containsKey("x-obmcs-header-collection")
                && mapVendorExtensions.containsKey("x-obmcs-prefix") )
            {
                HeaderParameter headerParam = (HeaderParameter)param;
                if (!headerParam.getType().equals("object"))
                {
                    LOGGER.info("Applying x-obmcs-prefix to header parameter " + param.getName());
                    StringProperty strProp = new StringProperty(headerParam.getFormat());
                    headerParam.setItems(strProp);
                    headerParam.setType("object");
                    String name = headerParam.getName();
                    if (name.endsWith("*") && name.length() > 1);
                        headerParam.setName(name.substring(0, name.length() - 1));
                }
            }
        }

        /*
         * Call super.
         */
        CodegenParameter codegenParameter = super.fromParameter(param, imports);
        //LOGGER.info("iprt/fromParameter: codegenParameter=" + codegenParameter);

        /* Make sure the vendor extensions are unique. */
        codegenParameter.vendorExtensions = copyVendorExtensions(codegenParameter.vendorExtensions, "fromParameter");

        /*
         * Correct defaultValue.
         */
        if (codegenParameter.defaultValue != null)
            if (codegenParameter.dataType.equals("RTCRestString"))
                codegenParameter.defaultValue = "\"" + codegenParameter.defaultValue + "\"";

        /*
         * Implement x-obmcs-enumref.   These seems to reference enums defined in
         * the data model.  For instance:
         *      x-obmcs-enumref: '#/definitions/Volume/lifecycleState'
         *
         * In the model we have  generate Volume::LifecycleStateEnum , so transforming
         * this should be reasonably simple.
         */
        if (codegenParameter.vendorExtensions.containsKey("x-obmcs-enumref"))
        {
            String strEnumRef = (String)codegenParameter.vendorExtensions.get("x-obmcs-enumref");
            if (strEnumRef == null)
                LOGGER.warn("x-obmcs-enumref is null?");
            else if (strEnumRef.startsWith("#/definitions/"))
            {
                String aParts[] = strEnumRef.substring(14).split("/");
                if (aParts.length == 2)
                {
                    String strEnumName = toEnumNameByString(aParts[1]);
                    String strEnumType = aParts[0] + "::" + strEnumName;
                    if (!codegenParameter.isContainer)
                    {
                        codegenParameter.dataType         = strEnumType;
                        codegenParameter.datatypeWithEnum = strEnumType;
                        codegenParameter.enumName         = strEnumName;
                        codegenParameter.isEnum           = true;
                        codegenParameter.vendorExtensions.put(X_IS_ENUM_TYPE, "true");
                        codegenParameter.vendorExtensions.put(X_CONST_REF_DATATYPE, strEnumType + " const &");
                        codegenParameter.vendorExtensions.remove(X_IS_STRING_TYPE);
                    }
                    else
                        LOGGER.warn("Unable handle x-obmcs-enumref=" + strEnumRef + ": isContainer=true");
                }
                else
                    LOGGER.warn("Unable handle x-obmcs-enumref=" + strEnumRef + ": aParts=" + aParts);
            }
            else
                LOGGER.warn("Unable handle x-obmcs-enumref=" + strEnumRef);
        }

        return codegenParameter;
    }

    /** Camel cased constant names. */
    @Override
    public String toEnumVarName(String name, String datatype)
    {
        if (name.length() == 0)
            return "EMPTY";
        return camelize(name.replaceAll("\\W+", "_"));
    }

    /** Super doesn't get dash-filled header fields right. */
    private String toEnumNameByString(String strName)
    {
        String strEnumName = camelize(strName) + "Enum";
        //LOGGER.info("iprt/toEnumNameByString: property=" + property + " -> " + strEnumName);
        return strEnumName;
    }

    /** Super doesn't get dash-filled header fields right. */
    @Override
    public String toEnumName(CodegenProperty property)
    {
        return toEnumNameByString(property.name);
    }

    /**
     * Copies a vendor extension map to ensure it's can be updated uniquely.
     *
     * The code in DefaultCodegen.java generally just uses the vendorExtension
     * property from the swagger property directly, thus we end up sharing when
     * references are in play.  This must be prevent as enums types are
     * prefixed with request/response class name, making them context dependent.
     */
    private Map<String, Object> copyVendorExtensions(Map<String, Object> src, String debugHint)
    {
        if (!src.containsKey("x-cg-copied-vendor-extensions"))
        {
            Map<String, Object> dst = new HashMap<String, Object>();
            dst.putAll(src);
            dst.put("x-cg-copied-vendor-extensions", debugHint);
            return dst;
        }
        return src;
    }

    /**
     * For flagging polymorphic parameters (and optionally logging stuff).
     */
    public Map<String, Object> postProcessOperationsWithModels(Map<String, Object> objs, List<Object> allModels)
    {
        //LOGGER.info("iprt/postProcessOperationsWithModels: allModels="+allModels.size());
        Map<String, Object>     operations    = (Map<String, Object>) objs.get("operations");
        List<CodegenOperation>  operationList = (List<CodegenOperation>) operations.get("operation");
        Map<String, Object>     modelMap      = null;
        for (CodegenOperation op : operationList)
        {
            //LOGGER.info(" operation: " + op.nickname);
            for (CodegenParameter codegenParam : op.allParams)
            {
                /* Mark polymorphic stuff: */
                if (   !codegenParam.isContainer
                    && !codegenParam.isPrimitiveType
                    && codegenParam.dataType != null
                    && !codegenParam.dataType.startsWith("RTCRest"))
                {
                    if (modelMap == null)
                    {
                        modelMap = new HashMap<>();
                        for (Object o : allModels)
                        {
                            HashMap<String, Object> mapInner = (HashMap<String, Object>)o;
                            CodegenModel codegenModel = (CodegenModel)mapInner.get("model");
                            modelMap.put(codegenModel.name, codegenModel);
                        }
                    }

                    CodegenModel dataTypeModel = (CodegenModel)modelMap.get(codegenParam.dataType);
                    if (   dataTypeModel != null
                        && dataTypeModel.hasChildren)
                    {
                        LOGGER.info("Parameter '" + codegenParam.baseName + "' (type: " + codegenParam.dataType + ") is polymorphic!");
                        codegenParam.vendorExtensions.put(X_IS_POLYMORPHIC, "true");
                    }
                }

                /* Logging: */
                //String constType = (String)codegenParam.vendorExtensions.get(X_CONST_REF_DATATYPE);
                //if (codegenParam.enumName != null)
                //    LOGGER.info("   param: " + codegenParam.paramName + " type: " + codegenParam.dataType + " constType: " + constType + " enumName: " + codegenParam.enumName);
                //else
                //    LOGGER.info("   param: " + codegenParam.paramName + " type: " + codegenParam.dataType + " constType: " + constType );
                //LOGGER.info("          vendor extensions: " + codegenParam.vendorExtensions);
            }
        }

        return objs;
    }
}

