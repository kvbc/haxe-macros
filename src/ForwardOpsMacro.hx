package;

import haxe.macro.Context;
import haxe.macro.Type;
import haxe.macro.Expr;

class ForwardOpsMacro {
    static private function assertAbstract (type: Type): Void {
        if (!type.match(TAbstract(_,_)))
            Context.error('type $type expected to be an Abstract', Context.currentPos());
    }

    static private function getAbstractRef (type: Type): Ref<AbstractType> {
        assertAbstract(type);
        return switch (type) {
            case TAbstract(ref, _):
                ref;
            case _: throw "Error";
        }
    }

    static private function wrapExpr (exprDef: ExprDef): Expr {
        return {
            expr: exprDef,
            pos: Context.currentPos()
        }
    }

    macro static public function build (localTypePath: String, baseTypePath: String): Array<Field> {
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

            var newArgs = [];
            var exprDef: ExprDef = {
                var castedThis: Expr = wrapExpr(ECast(
                    wrapExpr(EConst(CIdent("this"))),
                    baseComplexType
                ));

                switch (staticField.meta.extract(':op')[0].params[0].expr) {
                    case EBinop(op, e1, e2):
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
        
                        var arg = args[1]; // 
                        var isBaseType: Bool = (getAbstractRef(arg.t).toString() == baseAbstractRef.toString());
            
                        var newArgType: ComplexType = if (isBaseType) {
                            localComplexType;
                        } else {
                            Context.toComplexType(arg.t);
                        }
            
                        var newArg: FunctionArg = {
                            name: arg.name,
                            opt: arg.opt,
                            type: newArgType
                            // value?
                            // meta?
                        };
                        newArgs.push(newArg);

                        var castedNewArg: Expr = wrapExpr(ECast( // casted newArg
                            wrapExpr(EConst(CIdent(newArg.name))),
                            baseComplexType
                        ));

                        EBinop(op, castedThis, castedNewArg);
                    case EUnop(op, postFix, e):
                        EUnop(op, postFix, castedThis);
                    case _: throw "Error";
                }
            }

            var newFunc: Function = {
                args: newArgs,
                ret: localComplexType,
                expr: macro return ${wrapExpr(exprDef)}
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
