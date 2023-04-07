package;

import haxe.macro.Context;
import haxe.macro.Type;
import haxe.macro.Expr;

class ForwardOpsMacro {
    macro static public function build (localTypePath: String, baseTypePath: String): Array<Field> {
        function assertAbstract (type: Type): Void {
            if (!type.match(TAbstract(_,_)))
                Context.error('type $type expected to be an Abstract', Context.currentPos());
        }

        function getAbstractRef (type: Type): Ref<AbstractType> {
            assertAbstract(type);
            return switch (type) {
                case TAbstract(ref, _):
                    ref;
                case _: throw "Error"; // should be an abstract type by now
            }
        }

        var localComplexType: ComplexType = {
            var localType: Type = Context.getType(localTypePath);
            assertAbstract(localType);
            Context.toComplexType(localType);
        }

        var baseType: Type = Context.getType(baseTypePath);
        var baseComplexType: ComplexType = {
            assertAbstract(baseType);
            Context.toComplexType(baseType);
        }
        var baseAbstractRef: Ref<AbstractType> = getAbstractRef(baseType);

        var fields = Context.getBuildFields();

        for (staticField in baseAbstractRef.get().impl.get().statics.get()) {
            if (!staticField.meta.has(":op"))
                continue;

            var newArgs = new Array<FunctionArg>();

            var type: Type = staticField.type;
            // Extract the actual type if the type is TLazy
            type = switch(type) {
                case TLazy(_ => _() => actualType):
                    actualType;
                case _: type;
            }

            var args = switch (type) {
                case TFun(__args, _):
                    __args;
                case _: throw "Error"; // static fields with @:op should always be functions
            }

            // skip the first argument - this
            for (i in 1 ... args.length) {
                var arg = args[i];
                var isBaseType: Bool = (getAbstractRef(arg.t).toString() == baseAbstractRef.toString());

                var newArgType: ComplexType = if (isBaseType) {
                    localComplexType;
                } else {
                    Context.toComplexType(arg.t);
                }

                newArgs.push({
                    name: arg.name,
                    opt: arg.opt,
                    type: newArgType
                    // value?
                    // meta?
                });
            }

            var name = staticField.name;
            var newFunc: Function = {
                args: newArgs,
                ret: localComplexType,
                expr: macro return this.$name(other)
                // params?
            }

            fields.push({
                name: staticField.name,
                doc: staticField.doc,
                access: [staticField.isPublic ? APublic : APrivate], // inherit access modifier
                kind: FFun(newFunc),
                pos: staticField.pos,
                meta: staticField.meta.get()
            });
        }

        return fields;
    }
}