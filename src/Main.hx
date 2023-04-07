package;

@:transitive
abstract A(Int) from Int to Int {
    @:op(A + B)
    public function add (other: A): A {
        return (this: Int) + (other: Int);
    }

    @:op(A - B)
    public function sub (other: A): A {
        return (this: Int) - (other: Int);
    }
}

@:transitive
@:build(ForwardOpsMacro.build("B", "A"))
abstract B(A) from A to A {}

@:build(ForwardOpsMacro.build("C", "B"))
abstract C(B) from B to B {}

class Main {
	static private function main() {
        var a: C = 68;
        var b: C = 1;
        var c: C = a + b;
        trace(c);
	}
}
