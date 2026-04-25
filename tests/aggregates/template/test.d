module test;

mixin template Mixin(){}

template Empty(){}

template Type(T){}
template TypeSpec(T : int){}
template TypeValue(T = int){}

template Alias(alias A){}
template AliasSpec(alias A : int){}
template AliasValue(alias A = int){}

template Value(int I){}
template ValueSpec(int I : 0){}
template ValueValue(int I = 0){}

template Tuple(T...){}