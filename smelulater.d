import std.stdio;
import std.format;
import std.bigint;
import std.conv;
import std.range;
import std.algorithm;

import gmp_wrapper;

void main(string[] args) {
    string prompt = args[1];
    writeln(prompt);
    auto words = Word(prompt);
    writeln(words);
    auto tokens = Token(words);
    writeln(tokens);
    auto evaluated = evaluate(tokens);
    writeln(evaluated);
}

Token evaluate(Token[] tokens) {
    /* TODO: rework this and add parentheses support */
    for (auto opKind = Operator.Kind.init; opKind <= Operator.Kind.max; opKind++) {
        bool opFound;
        do {
            opFound = false;
            foreach (i, t; tokens) {
                Operator op = cast(Operator) t;
                if (t.tokenKind == Token.Kind.Operator && op.kind == opKind) {
                    opFound = opFound || true; // pity. D doesn't support ||=
                    tokens[i] = op(cast(Value) tokens[i-1], cast(Value) tokens[i+1]);
                    if (tokens[i].tokenKind == Token.Kind.Fail)
                        return tokens[i];
                    tokens = tokens.remove(i-1, i+1);
                    break;
                }
            }
        } while (opFound);
    }
    assert(tokens.length == 1);
    return tokens[0];
}

Token evaluate(R)(R tokens) => evaluate(tokens.array());

interface Token {
    static enum Kind { Operator, Number, Time, Fail }
    @property Kind tokenKind() const;
    static Token opCall(Word w) {
        switch (w.kind) {
        case Word.Kind.Number:
            if (w.contents.canFind!((c) => Time.units.canFind!((u) => c == u.second))) {
                BigInt time;
                uint n;
                foreach (c; w.contents) {
                    foreach (u; Time.units)
                        if (c == u.second) {
                            time += n * u.first;
                            n = 0;
                            goto next;
                        }
                    if (n > 0) n *= 10;
                    n += c - '0';
                next:
                }
                return new Time(time);
            }
            Number n = new Number(w.contents);
            return n;
        case Word.Kind.Operator:
            with (Operator.Kind) switch (w.contents) {
            case "*": return new Operator(Times);
            case "/": return new Operator(DividedBy);
            case "+": return new Operator(Plus);
            case "-": return new Operator(Minus);
            default: throw new Exception(format("Unknown operator %s", w.contents));
            }
        case Word.Kind.Unknown:
            throw new Exception("WHUT");
        default:
            return null;
        }
    }
    static auto opCall(R)(R words) =>
        words.map!(w => Token(w));
}

interface Value : Token {}

class Operator : Token {
    override @property smelulater.Token.Kind tokenKind() const => Token.Kind.Operator;
    static enum Kind {Times, DividedBy, Plus, Minus} // in order of precedence
    Kind kind;
    this(Kind k) {
        kind = k;
    }
    Value opCall(in Value left, in Value right) {
        auto kinds = [left.tokenKind, right.tokenKind];
        if (kinds == [Token.Kind.Number, Token.Kind.Time])
            return opCall(right, left);
        if (kinds == [Token.Kind.Time, Token.Kind.Number]) {
            if (kind == Kind.Times) 
                return new Time((cast(Number) right) * new Mpf(&(cast(Time) left).time));
            goto fail;
        }
        if (kinds == [Token.Kind.Number, Token.Kind.Number]) {
            const auto a = cast(Number) left;
            const auto b = cast(Number) right;
            Mpf value = new Mpf;
            switch (kind) {
            case Kind.Times:
                value = a * b;
                break;
            case Kind.DividedBy:
                value = a / b;
                break;
            case Kind.Plus:
                value = a + b;
                break;
            case Kind.Minus:
                value = a - b;
                break;
            default:
                goto fail;
            }
            return new Number(value);
        }
        if (kinds == [Token.Kind.Time, Token.Kind.Time]) {
            switch (kind) {
            default:
                goto fail;
            }
        }
        fail:
            return new Fail(format("Can't do %s with ‘%s’ and ‘%s’", kind, left, right));
    }
    override string toString() const {
        with (Kind) final switch(kind) {
        case Plus: return "Plus";
        case Minus: return "Minus";
        case Times: return "Times";
        case DividedBy: return "DividedBy";
        }
    }
}

class Time : Value {
    override @property smelulater.Token.Kind tokenKind() const => Token.Kind.Time;
    import core.stdcpp.utility : pair;
    BigInt time;
    const hour = 3600;
    const minute = 60;
    this() {}
    this(BigInt time) {
        this.time = time;
    }
    this(const Mpf mpf) {
        time = mpf.toString(); // haha
    }
    public static const pair!(int, char)[] units = [ {hour, 'h'}, {minute, 'm'}, {1, 's'} ];
    override string toString() const {
        import std.array : appender;
        auto result = appender!string();
        BigInt time = this.time;
        if (time < 0) {
            time *= -1;
            write('-');
        }
        foreach (u; units)
            if (time >= u.first) {
                formattedWrite(result, "%d%s", time / u.first, u.second);
                time %= u.first;
            }
        auto r = result[];
        return r.length ? r : "0s";
    }
}

class Number : Value {
    override @property smelulater.Token.Kind tokenKind() const => Token.Kind.Number;
    Mpf value;
    alias value this;
    this(Mpf value) { this.value = value; }
    this() { value = new Mpf; }
    this(string s) { value = new Mpf(s); }
    this(uint value) {
        this();
        this.value = value; 
    }
    override string toString() const => value.toString;
}

class Fail : Value {
    override @property smelulater.Token.Kind tokenKind() const => Token.Kind.Fail;
    string message;
    this(string message) {
        this.message = message;
    }
    override string toString() const => message;
}

struct Word {
    enum Kind { Unknown, Number, Operator }
    Kind kind;
    string contents;
    static Word[] opCall(const string s) {
        import std.ascii;
        Word[] words;
        Word word;
        void nextWord() {
            if (word.kind != 0) {
                words ~= word;
                word.kind = Word.Kind.Unknown;
                word.contents = null;
            }
        }
        foreach (c; s) {
            if (isWhite(c)) {
                nextWord();
                continue;
            }
        back:
            with (Word.Kind) final switch (word.kind) {
            case Unknown: // new word
                switch (c) {
                case '0': .. case '9':
                    word.kind = Number;
                    break;
                case '+', '-', '*', '/':
                    word.kind = Operator;
                    break;
                default:
                    assert(false, format("Trouble parsing \"%s\"", s));
                }
                break;
            case Number:
                if (c == '+' || c == '-' || c == '*' || c == '/') {
                    nextWord();
                    goto back;
                }
                break;
            case Operator:
                if (c >= '0' && c <= '9') {
                    nextWord();
                    goto back;
                }
                break;
            }
            word.contents ~= c;
        }
        nextWord();
        return words;
    }
    string toString() const => format("%s:%s", kind, contents);
}