module gmp_wrapper;

import deimos.gmp;
import std.stdio;
import std.bigint;
import std.conv;

private {
    extern (C) int __gmp_asprintf(char**, const char*, ...);
    alias gmp_asprintf = __gmp_asprintf;
}

final class Mpf {
    private __mpf_struct value;
    alias value this;
    this() {
        mpf_init(&value);
    }
    this(ref in Mpf other) {
        this();
        mpf_set(&this.value, &other.value);
    }
    this(int value) {
        // TODO: something better that handles bigger values
        this();
        this = value;
    }
    this(in string s) {
        this();
        import std.string : toStringz;
        mpf_set_str(&value, s.toStringz, 10);
    }
    this(in BigInt *value) {
        this(value.to!int);
    }
    void opAssign(uint value) {
        mpf_set_ui(&this.value, value);
    }
    Mpf opBinary(string op : "*")(const Mpf rhs) const {
        Mpf n = new Mpf;
        mpf_mul(&n.value, &value, &rhs.value);
        return n;
    }
    Mpf opBinary(string op : "/")(const Mpf rhs) const {
        Mpf n = new Mpf;
        mpf_div(&n.value, &value, &rhs.value);
        return n;
    }
    Mpf opBinary(string op : "+")(const Mpf rhs) const {
        Mpf n = new Mpf;
        mpf_add(&n.value, &value, &rhs.value);
        return n;
    }
    Mpf opBinary(string op : "-")(const Mpf rhs) const {
        Mpf n = new Mpf;
        mpf_sub(&n.value, &value, &rhs.value);
        return n;
    }
    int opCmp(int other) const {
        return mpf_cmp_si(&value, other);
    }
    override string toString() const {
        char *buf;
        gmp_asprintf(&buf, "%.*Ff", !mpf_integer_p(&value), &value);
        return buf.to!string;
    }
    ~this() {
        mpf_clear(&value);
    }
}
