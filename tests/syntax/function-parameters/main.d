/// This is a function.
void func(
    int a, 
    bool b,
    string c,
    S d,
    C e,
    I f,
    T!int g,
){}

void func2(
    const int a,
    immutable bool b,
    scope ref return string c,
){}

struct S {}
class C {}
interface I {}

struct T(alias a) {}