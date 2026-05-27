module marmos.converter.model;

import std;
import marmos.converter.json ;

/++++ Definitions ++++/

alias DocAggregateDef = SumType!(
    DocClass,
    DocUnion,
    DocEnum,
    DocTemplate,
);

alias DocTypeRefRaw = SumType!(
    DocSymbolReference,
    DocArrayType,
    DocAssociativeArrayType,
    DocStaticArrayType,
    DocFunctionType,
    DocBasicType,
    DocPointerType,
);

alias DocSymbolReferenceItem = SumType!    DocSymbolDirectReference;

template DocAggregateCommon()
{
    DocAggregateDef[] nestedTypes;
}

struct DocModelRoot
{
    DocModule module_;
}

struct DocModule
{
    mixin DocAggregateCommon;
}

/++ Aggregates ++/

@JsonType("DocClass@1")
struct DocClass
{
    mixin DocAggregateCommon;

    DocTypeRef[] interfaces;
}

struct DocEnum
{
}

struct DocUnion
{
}

struct DocTemplate
{
}

struct DocRuntimeParameter
{
    string                  name;
    DocTypeRef              typeRef;
}

struct DocTypeRef
{
    DocTypeRefRaw raw;
}

struct DocFunctionType
{
    DocRuntimeParameter[] parameters;
}

struct DocArrayType
{
}

struct DocAssociativeArrayType
{
}

struct DocStaticArrayType
{
}

struct DocBasicType
{
}

struct DocPointerType
{
}

/++ Symbol Reference ++/

@JsonType("DocSymbolReference@1")
struct DocSymbolReference
{
    DocSymbolReferenceItem[] items;
}

struct DocSymbolDirectReference
{
}

