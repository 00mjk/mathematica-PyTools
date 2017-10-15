(* ::Package:: *)



ToPython::usage=
	"Specifies how to turn a symbolic structure into a string";
SymbolicPythonQ::usage=
	"Gives True if a symbol is a known symbolic python structure";
ToSymbolicPython::usage=
	"Generates symbolic python from a WL expression";
PyAlias::usage=
	"Generates an alias for a lower-level form to be called with ToPython";


(*PythonRun::usage=
	"Runs a chunk of python code or a file";
PythonStart::usage=
	"Starts an interactive python process";
PythonKill::usage=
	"Kills the current python process";*)


Begin["`Private`"];


(* ::Subsection:: *)
(*Basics*)



ClearAll/@Values@$PyAliases//Quiet;
ClearAll/@Values@$PyStructures//Quiet;
Clear@"@Py*";


(* ::Subsubsection::Closed:: *)
(*Structures*)



$PyStructures=<|
	
	|>;
With[{$cont=$Context},
ToPython/:
	HoldPattern[(h:Set|SetDelayed)[ToPython[a_]/;(!TrueQ@$PythonInDef),v_]]:=
		With[{sym=FirstCase[Hold[a],_Symbol,None,{2,\[Infinity]},Heads->True]},
			If[sym=!=None,
				If[Context[sym]==$cont,
					Context[sym]=Context@ToPython
					];
				$PyStructures[StringTrim[SymbolName[sym],"Py"]]=
					sym;
				sym::usage=("Symbolic python form of a "<>StringTrim[SymbolName[sym],"Py"])
				];
				Block[{$PythonInDef=True},
					h[
						ToPython[a],
						ToPythonWrapper[v]
						]
					]
				]
	];


(* ::Subsubsection::Closed:: *)
(*Aliases*)



$PyAliases=
	<|
		|>;
With[{$cont=$Context},
PyAlias/:
	HoldPattern[(h:Set|SetDelayed)[PyAlias[a_],v_]]:=
		With[{sym=FirstCase[Hold[a],_Symbol?(Not@*MatchQ[Hold]),None,\[Infinity],Heads->True]},
			If[sym=!=None,
				$PyAliases[StringTrim[SymbolName[sym],"Py"]]=
					sym;
				If[Context[sym]==$cont,
					Context[sym]=Context@ToPython
					];
				sym::usage=("Symbolic python form of a "<>StringTrim[SymbolName[sym],"Py"]);
				h[ToPython[a],ToPython@v]
				]
			];
	]


(* ::Subsubsection::Closed:: *)
(*Wrapper*)



$PyHeadOncePatterns=
	_PyImport|_PyFromImport|_PyFromImportAs;


ToPythonWrapper[a_]/;!TrueQ[$PythonInCall]:=
	Block[{$PythonInCall=True},
		Replace[Reap[a,"PyHead"],{
			{base_,{}}:>base,
			{base_,head_}:>
				ToPython[
					PyColumn[
						Flatten@{
							DeleteDuplicates@
								Cases[Flatten@List@head,
									$PyHeadOncePatterns
									],
							Cases[Flatten@List@head,
								Except[$PyHeadOncePatterns]
								],
							base
							}
						]
					]
			}]
		];
ToPythonWrapper[a_]/;TrueQ[$PythonInCall]:=a;
ToPythonWrapper~SetAttributes~HoldAllComplete


(* ::Subsubsection::Closed:: *)
(*SymbolicPythonQ*)



SymbolicPythonQ[s_]:=
	Catch@With[{
		sym=
			FirstCase[Hold[s],
				sym_Symbol(*?(Not@*MatchQ[Hold])*):>Unevaluated[sym],
				Throw[False],
				{2,\[Infinity]},
				Heads->True]
			},
		MemberQ[Join@@Values/@{$PyStructures,$PyAliases},sym]
		]&&
		Replace[Unevaluated@ToPython[s],
			Append[
				Thread[(First/@DownValues[ToPython])->True],
				_->False
				]
			];
SymbolicPythonQ~SetAttributes~HoldFirst


(* ::Subsubsection::Closed:: *)
(*Heads*)



PyHeadSow[i_]/;TrueQ[$PythonInCall]:=
	(
		Sow[i,"PyHead"];
		Sequence@@{}
		)


PyImportSow[import_]/;TrueQ[$PythonInCall]:=
	PyHeadSow[PyImport[import]];
PyImportAsSow[import_,as_]/;TrueQ[$PythonInCall]:=
	PyHeadSow[PyImportAs[import,as]];
PyFromImportSow[from_,import_]/;TrueQ[$PythonInCall]:=
	PyHeadSow[PyFromImport[from,import]];
PyFromImportAsSow[from_,import_,as_]/;TrueQ[$PythonInCall]:=
	PyHeadSow[PyFromImportAs[from,import,as]];


ToPython[PyImportSow[i_]]:=
	Block[{$PythonInCall=True},
		PyImportSow@i
		];
ToPython[PyImportAsSow[import_,as_]]:=
	Block[{$PythonInCall=True},
		PyImportAsSow[import,as]
		];
ToPython[PyFromImportSow[from_,import_]]:=
	Block[{$PythonInCall=True},
		PyFromImportSow[from,import]
		];
ToPython[PyFromImportAsSow[from_,import_,as_]]:=
	Block[{$PythonInCall=True},
		PyFromImportAsSow[from,import,as]
		];


(* ::Subsection:: *)
(*Atomics*)



(* ::Subsubsection::Closed:: *)
(*String*)



$PyStringChar="'";
ToPython@
	PyString[s_String,char:_String|Automatic|None:Automatic]:=
		With[{sc=
			Replace[char,
				Automatic:>
					If[Length@StringCases[s,EndOfLine,3]>1,
						StringRepeat[$PyStringChar,3],
						$PyStringChar
						]
				]},
			If[MatchQ[sc,_String?(StringLength@#>0&)],
				StringJoin@{sc,
					StringTrim[s,sc],
					sc},
				s
				]
			];


(* ::Subsubsection::Closed:: *)
(*Symbol*)



(*PySymbol[e:Except[_Symbol|_String]]:=
	PySymbol@ToPython[e],
PySymbol~SetAttributes~HoldAllComplete*)


ToPython[PySymbol[s_String]]:=
	StringReplace["$"->"_"]@
	With[{splits=StringSplit[s,"`"]},
		If[MemberQ[splits,"Private"|"PackageScope"|"PackagePrivate"]||
			MatchQ[splits[[1]],"System`"|"Global`"],
			Last[splits],
			ToPython[PyDot@@s]
			]
		];
ToPython[PySymbol[s_Symbol]]:=
	StringReplace["$"->"_"]@
	With[{cont=Context[s]},
		If[StringContainsQ[cont,"Private"|"PackageScope"|"PackagePrivate"]||
			MatchQ[cont,"System`"|"Global`"],
			SymbolName@Unevaluated[s],
			PyDot@@Append[StringSplit[cont,"`"],SymbolName@Unevaluated[s]]//ToPython
			]
		];


(* ::Subsubsection::Closed:: *)
(*Numerics*)



toNumberString[n_?NumericQ]:=
	ToString@NumberForm[n,ExponentFunction->(Null&)]


ToPython[PyInt[i_?NumericQ]]:=
	toNumberString@IntegerPart[i];
ToPython[PyFloat[n_?NumericQ,prec:_Integer|Automatic:Automatic]]:=
	toNumberString@If[prec===Automatic,N[n],N[n,prec]];
ToPython@PyVerbatim[v_]:=
	ToString[v];


(* ::Subsubsection::Closed:: *)
(*Booleans*)



ToPython@PyBoolean[True]:=
	"True";
ToPython@PyBoolean[False]:=
	"False";
PyAlias[PyTrue]:=
	PyBoolean[True];
PyAlias[PyFalse]:=
	PyBoolean[False];


(* ::Subsection:: *)
(*MultiPart*)



(* ::Subsubsection::Closed:: *)
(*List*)



ToPython[PyList[l_List]]:=
	StringJoin@{"[ ",Riffle[ToPython/@l,", "]," ]"};


(* ::Subsubsection::Closed:: *)
(*Tuple*)



ToPython[PyTuple[l_List]]:=
	StringJoin@{"( ",Riffle[ToPython/@l,", "]," )"};


(* ::Subsubsection::Closed:: *)
(*Set*)



ToPython[PySet[l_List]]:=
	StringJoin@{"{ ",Riffle[ToPython/@l,", "]," }"};


(* ::Subsubsection::Closed:: *)
(*Rule*)



$PyRuleChar="=";
ToPython@PyRule[a_,b_,rs:_String|Automatic:Automatic]:=
	StringJoin@{ToPython[a],Replace[rs,Automatic->$PyRuleChar],ToPython[b]};
ToPython@PyRule[a_->b_,rs:_String|Automatic:Automatic]:=
	ToPython@PyRule[a,b,rs];
ToPython@PyRule[a_:>b_,rs:_String|Automatic:Automatic]:=
	ToPython@PyRule[a,b,rs];


(* ::Subsubsection::Closed:: *)
(*Dict*)



ToPython[PyDict[l_List]]:=
	StringJoin@{"{ ",Riffle[Block[{$PyRuleChar=":"},ToPython/@Normal@l],", "]," }"};
ToPython[PyDict[a_Association]]:=
	ToPython[PyDict[Normal@a]];


(* ::Subsubsection::Closed:: *)
(*Sequence*)



ToPython[PySequence[args_List]]:=
	StringJoin@Riffle[ToPython/@args,", "];


(* ::Subsection:: *)
(*WL*)



ToPython[Null]:=
	"";


ToPython[Pi]:=
	(
		PyImportSow["math"];
		ToPython@PyDot["math","pi"]
		);


ToPython[E]:=
	(
		PyImportSow["math"];
		ToPython@PyDot["math","e"]
		);


ToPython[Infinity]:=
	(
		PyImportSow["math"];
		ToPython@PyDot["math","inf"]
		);


ToPython[-Infinity]:=
	(
		PyImportSow["math"];
		ToPython@PyMinus@PyDot["math","inf"]
		);


ToPython[I]:=
	(
		PyImportSow["math"];
		ToPython@PyMinus@PyDot["math","i"]
		);


ToPython[s_String]:=
	s;
ToPython[s_Symbol]:=
	ToPython@PySymbol[s];
ToPython[i_Integer]:=
	ToPython@PyInt[i];
ToPython[r_Real]:=
	ToPython@PyFloat[r];
ToPython[t:True|False]:=
	ToPython@PyBoolean[t];
ToPython[r:_Rule|_RuleDelayed]:=
	ToPython@PyRule[r];
ToPython[r:_Association|{(_Rule|_RuleDelayed)..}]:=
	ToPython@PyDict[r];
ToPython[l_List]:=
	ToPython@PyList[l];


ToPython[n_?NumericQ]:=
	n//.{
		HoldPattern@Times[Rational[1,b_],c_]:>
			ToPython@PyDivide[c,b],
		HoldPattern@Times[Rational[a_,b_],c_]:>
			ToPython@PyDivide[PyMultiply[a,c],b],
		HoldPattern@Times[a__]:>ToPython@PyMultiply[a],
		HoldPattern@Divide[a__]:>ToPython@PyDivide[a],
		HoldPattern@Rational[a_,b_]:>ToPython@PyDivide[a,b],
		HoldPattern@Subtract[a__]:>ToPython@PyMinus[a],
		HoldPattern@Plus[a__]:>ToPython@PyPlus[a]
		}


ToPython[Slot[n_]]:=
	"pyArg_"<>ToString[n];
ToPython[SlotSequence[]]:=
	"pyArgTuple"
ToPython[SlotSequence[n_]]:=
	"pyArgTuple[n:]"


(* ::Subsection:: *)
(*Structures*)



ToPython@PyRow[args_List,riffle:_String:""]:=
	StringJoin@Riffle[ToPython/@args,riffle]


$PyIndentLevel=0;
ToPython@PyBlock[
	head_:Nothing,
	indent:_Integer:1,
	separator:_String:""
	][args:{__}]:=
	Block[{$PyIndentLevel=$PyIndentLevel+indent},
		StringJoin@Riffle[Flatten@{
			Replace[head,{
				l_List:>
					ToPython@PyRow[l],
				e:Except[Nothing]:>
					ToPython@e
				}],
			ToPython/@args
			},
			separator<>"\n"<>If[$PyIndentLevel>0,StringRepeat["\t",$PyIndentLevel],""]
			]<>"\n"
		];
ToPython@PyBlock[e__][a:Except[_List],b___]:=
	ToPython@PyBlock[e][{a,b}];


PyAlias@PyColumn[c__]:=
	PyBlock[Nothing,0][c];


PyAlias@
	PyWrap[{l_,r_}][a_]:=
		PyRow[{l,a,r}," "];
PyAlias@
	PyWrap[][a_]:=
		PyWrap[{"( "," )"}][a];


(* ::Subsection:: *)
(*Commands*)



PyAlias@PyCommand[c_][args__]:=
	PyRow[{c,PyRow[{args},", "]}," "];


PyAlias@PyAs[arg_]:=
	PyCommand["as"][arg];


PyAlias@PyAssert[test_]:=
	PyCommand["assert"][test];


PyAlias@PyBreak[]:=
	PyCommand["break"][];


PyAlias@PyContinue[]:=
	PyCommand["continue"][""];


PyAlias@PyDel[arg_]:=
	PyCommand["del"][arg];


PyAlias@PyFrom[arg_]:=
	PyCommand["from"][arg];


PyAlias@PyGlobal[args__]:=
	PyCommand["global"][args];


PyAlias@PyImport[args__]:=
	PyCommand["import"][Replace[args,_List:>PySequence[args]]];


PyAlias@PyPass[]:=
	PyCommand["pass"][""];


PyAlias@PyRaise[err_:""]:=
	PyCommand["raise"][err];


PyAlias@PyReturn[v__]:=
	PyCommand["return"][v];


PyAlias@PyYield[v__]:=
	PyCommand["yield"][v];


(* ::Subsection:: *)
(*Operators*)



PyAlias@PyInfix[o_][a_,b__]:=
	PyRow[{a,b},o];


PyAlias@PyPlus[a_,b__]:=
	PyInfix["+"][a,b];


PyAlias@PyMinus[a_,b__]:=
	PyInfix["-"][a,b];


PyAlias@PyMultiply[a_,b__]:=
	PyInfix["*"][a,b];


PyAlias@PyDivide[a_,b__]:=
	PyInfix["/"][a,b];


PyAlias@PyMod[a_,b__]:=
	PyInfix["%"][a,b];


PyAlias@PyPower[a_,b__]:=
	PyInfix["**"][a,b];


PyAlias@PyFloorDiv[a_,b__]:=
	PyInfix["//"][a,b];


PyAlias@PyEqual[a_,b__]:=
	PyInfix["=="][a,b];


PyAlias@PyGreater[a_,b__]:=
	PyInfix[">"][a,b];


PyAlias@PyGreaterEqual[a_,b__]:=
	PyInfix[">="][a,b];


PyAlias@PyLess[a_,b__]:=
	PyInfix["<"][a,b];


PyAlias@PyLessEqual[a_,b__]:=
	PyInfix["<="][a,b];


PyAlias@PyAnd[a_,b__]:=
	PyInfix[" and "][a,b];


PyAlias@PyOr[a_,b__]:=
	PyInfix[" or "][a,b];


PyAlias@PyIn[a_,b__]:=
	PyInfix[" in "][a,b];


PyAlias@PyNotIn[a_,b__]:=
	PyInfix[" not in "][a,b];


PyAlias@PyIs[a_,b__]:=
	PyInfix[" is "][a,b];


PyAlias@PyIsNot[a_,b__]:=
	PyInfix[" is not "][a,b];


PyAlias@PySlice[a_,b__]:=
	PyInfix[":"][a,b];


PyAlias@PySuite[a_,b__]:=
	PyInfix[";"][a,b]


PyAlias@PyDot[a_,b__]:=
	PyInfix["."][a,b];


PyAlias@PyAssign[a_,b__]:=
	PyInfix[" = "][a,b];


PyAlias@PyAddTo[a_,b_]:=
	PyInfix[" += "][a,b];


PyAlias@PySubtractFrom[a_,b_]:=
	PyInfix[" -= "][a,b];


PyAlias@PyMultiplyBy[a_,b_]:=
	PyInfix[" *= "][a,b];


PyAlias@PyDivideBy[a_,b_]:=
	PyInfix[" /= "][a,b];


PyAlias@PyAndEqual[a_,b_]:=
	PyInfix[" &= "][a,b];


PyAlias@PyOrEqual[a_,b_]:=
	PyInfix[" |= "][a,b];


PyAlias@PyPrefix[o_][arg_]:=
	PyRow[{o,arg}];


PyAlias@PyNot[arg_]:=
	PyPrefix["not "][arg];


PyAlias@PyStar[arg_]:=
	PyPrefix["*"][arg];


PyAlias@PyDoubleStar[arg_]:=
	PyPrefix["**"][arg];


PyAlias@PyDecorator[arg_]:=
	PyPrefix["@"][arg];
PyAlias@PyDecorator[arg_][v__]:=
	PyColumn[
		PyDecorator[arg],
		v
		]


PyAlias@PyPlus[arg_]:=
	PyPrefix["+"][arg];


PyAlias@PyMinus[arg_]:=
	PyPrefix["-"][arg];


PyAlias@PyInvert[arg_]:=
	PyPrefix["~"][arg];


PyAlias@
	PyComment[s_]:=
		PyPrefix["#"][s];


(* ::Subsection:: *)
(*Blocks*)



PyAlias@
	PyClass[name_,
		inherit:(None|_List|_String|_Symbol|_PySymbol|_PyTuple):None][defs:{__}]:=
	PyBlock[
		PyRow[{"class ",name,
			Switch[inherit,
				None,
					Nothing,
				_List,
					PyRow@{"(",PySequence@inherit,")"},
				_PyTuple,
					PyRow@{"(",PySequence@@inherit,")"},
				_,
					PyRow@{"(",inherit,")"}
				],
			":"
			}]
		][defs];
PyAlias@
	PyClass[name_,
		inherit:(None|_List|_String|_Symbol|_PySymbol|_PyTuple):None][def:Except[_List]]:=
	PyClass[name,inherit][{def}];
PyAlias@
	PyClass[name_,
		inherit:(None|_List|_String|_Symbol|_PySymbol|_PyTuple):None][def_,defs__]:=
	PyClass[name,inherit][{def,defs}];


PyAlias@
	PyDef[name_,
		args:(None|_List|_String|_Symbol|_PySymbol|_PyTuple):None][def:{__}]:=
	PyBlock[
		PyRow[{"def ",name,
			Switch[args,
				None,
					PyRow@{"(",")"},
				_List,
					PyRow@{"(",PySequence@args,")"},
				_PyTuple,
					PyRow@{"(",PySequence@@args,")"},
				_,
					PyRow@{"(",args,")"}
				],
			":"
			}]
		][def];
PyAlias@
	PyDef[name_,
		args:(None|_List|_String|_Symbol|_PySymbol|_PyTuple):None][def:Except[_List]]:=
	PyDef[name,args][{def}];
PyAlias@
	PyDef[name_,
		inherit:(None|_List|_String|_Symbol|_PySymbol|_PyTuple):None][def_,defs__]:=
	PyDef[name,inherit][{def,defs}];


PyAlias@PyTry[val:{__}]:=
	PyBlock["try:"][val];
PyAlias@PyTry[val:Except[_List]]:=
	PyTry[{val}];
PyAlias@PyTry[val_,vals__]:=
	PyTry[{val,vals}];


PyAlias@PyExcept[err_][val:{__}]:=
	PyBlock[{"except ",err,":"}][val];
PyAlias@PyExcept[test_][val:Except[_List]]:=
	PyExcept[test][{val}];
PyAlias@PyExcept[test_][val_,vals__]:=
	PyExcept[test][{val,vals}];


PyAlias@PyTry[val:{__}]:=
	PyBlock["try:"][val];
PyAlias@PyTry[val:Except[_List]]:=
	PyTry[{val}];
PyAlias@PyTry[val_,vals__]:=
	PyTry[{val,vals}];


PyAlias@PyFor[iter_][val:{__}]:=
	PyBlock[{"for ",iter,":"}][val];
PyAlias@PyFor[iter_][val:Except[_List]]:=
	PyFor[iter][{val}];
PyAlias@PyFor[iter_][val_,vals__]:=
	PyFor[iter][{val,vals}];


PyAlias@PyIf[test_][val:{__}]:=
	PyBlock[{"if ",test,":"}][val];
PyAlias@PyIf[test_][val:Except[_List]]:=
	PyIf[test][{val}];
PyAlias@PyIf[test_][val_,vals__]:=
	PyIf[test][{val,vals}];


PyAlias@PyElIf[test_][val:{__}]:=
	PyBlock[{"elif ",test,":"}][val];
PyAlias@PyElIf[test_][val:Except[_List]]:=
	PyElIf[test][{val}];
PyAlias@PyElIf[test_][val_,vals__]:=
	PyElIf[test][{val,vals}];


PyAlias@PyElse[val:{__}]:=
	PyBlock["else:"][val];
PyAlias@PyElse[val:Except[_List]]:=
	PyElse[{val}];
PyAlias@PyElse[val_,vals__]:=
	PyElse[{val,vals}];


PyAlias@
	PyLambda[args:(None|_List|_String|_Symbol|_PySymbol|_PyTuple):None][
		{def_}|
		PyColumn[{def_}]
		]:=
	PyRow[{"( ",
		"lambda ",
			Switch[args,
				None,
					Nothing,
				_List,
					PySequence@args,
				_PyTuple,
					PySequence@@args,
				_,
					args
				],
			": ",
			def,
			" )"
			}]


PyAlias@
	PyLambda[args:(None|_List|_String|_Symbol|_PySymbol|_PyTuple):None][
		(defs:{__})|
		PyColumn[defs:{__}]
		]:=
	PyRow[{
		"( ",
		PyBlock[
		PyRow[{"lambda ",
			Switch[args,
				None,
					Nothing,
				_List,
					PySequence@args,
				_PyTuple,
					PySequence@@args,
				_,
					args
				],
			": ("
			}]
		][Append[Map[PyRow[{#,","}]&,defs],")[-1]"]],
		" )"
		}];
PyAlias@
	PyLambda[
		args:(None|_List|_String|_Symbol|_PySymbol|_PyTuple):None][def:Except[_List]]:=
	PyRow[{"( ","lambda ", 
			Switch[args,
				None,
					Nothing,
				_List,
					PySequence@args,
				_PyTuple,
					PySequence@@args,
				_,
					args
				],
			": ( ",
			def,
			" )",
			" )"
			}]
PyAlias@
	PyLambda[
		args:(None|_List|_Symbol|_String|_PySymbol|_PyTuple):None][def_,defs__]:=
	PyLambda[args][{def,defs}];
PyAlias@
	PyLambda[
		args:(None|_List|_Symbol|_String|_PySymbol|_PyTuple):None][a___][b___]:=
	PyCall[PyLambda[args][a]][b]


PyAlias@PyWhile[test_][val:{__}]:=
	PyBlock[{"while ",test,":"}][val];
PyAlias@PyWhile[test_][val:Except[_List]]:=
	PyWhile[test][{val}];
PyAlias@PyWhile[test_][val_,vals__]:=
	PyWhile[test][{val,vals}];


PyAlias@PyWith[dec_][val:{__}]:=
	PyBlock[{"with ",dec,":"}][val];
PyAlias@PyWith[dec_][val:Except[_List]]:=
	PyWith[dec][{val}];
PyAlias@PyWith[dec_][val_,vals__]:=
	PyWith[dec][{val,vals}];


(* ::Subsection:: *)
(*Calls and Index*)



PyAlias@PyIndex[a_,b__]:=
	PyRow@Flatten@{a,Map[{PyVerbatim@"[",#,PyVerbatim@"]"}&,{b}]};


PyAlias@PyCall[f_][args___]:=
	If[Length@{args}>5,
		PyBlock[{f,PyVerbatim@"("}][Append[Map[PyRow@{#,","}&,{args}],PyVerbatim@")"]],
		PyRow[{f,PyVerbatim@"(",PyRow[{args},", "],PyVerbatim@")"}]
		];


PyAlias@PyAbs[arg_]:=
	PyCall["abs"][arg];
PyAlias@PyAbs:=
	"abs";


PyAlias@PyAll[iter_]:=
	PyCall["all"][iter];
PyAlias@PyAll:=
	"all";


PyAlias@PyAny[iter_]:=
	PyCall["any"][iter]
PyAlias@PyAny:=
	"any";


PyAlias@PyAscii[arg_]:=
	PyCall["ascii"][arg]
PyAlias@PyAscii:=
	"ascii";


PyAlias@PyBin[arg_]:=
	PyCall["bin"][arg]


PyAlias@PyBool[arg_]:=
	PyCall["bool"][arg]


PyAlias@PyByteArray[args__]:=
	PyCall["bytearray"][args]


PyAlias@PyBytes[args__]:=
	PyCall["bytes"][args]


PyAlias@PyCallable[arg_]:=
	PyCall["callable"][arg]


PyAlias@PyChr[i_]:=
	PyCall["chr"][i]


PyAlias@PyClassMethod[f_]:=
	PyCall["classmethod"][f]


PyAlias@PyCompile[args__]:=
	PyCall["compile"][args]


PyAlias@PyComplex[args___]:=
	PyCall["complex"][args]


PyAlias@PyDelAttr[args__]:=
	PyCall["delattr"][args]


PyAlias@PyDict[i:Except[_List|_Association]]:=
	PyCall["dict"][i];
PyAlias@PyDict[i_,args__]:=
	PyCall["dict"][i,args];


PyAlias@PyDir[args___]:=
	PyCall["dir"][args]


PyAlias@PyDivMod[a_,b_]:=
	PyCall["divmod"][a,b]


PyAlias@PyEnumerate[args__]:=
	PyCall["enumerate"][args]


PyAlias@PyEval[args__]:=
	PyCall["eval"][args]


PyAlias@PyExec[args__]:=
	PyCall["exec"][args]


PyAlias@PyFilter[args__]:=
	PyCall["filter"][args]


PyAlias@PyFloat[i:Except[_?NumericQ]]:=
	PyCall["float"][i];
PyAlias@PyFloat[a_,b__]:=
	PyCall["float"][a,b];
PyAlias@PyFloat[]:=
	PyCall["float"][];


PyAlias@PyFormat[repr_,spec___]:=
	PyCall["format"][repr,spec]


PyAlias@PyFrozenSet[args___]:=
	PyCall["frozenset"][args]


PyAlias@PyGetAttr[args__]:=
	PyCall["getattr"][args]


PyAlias@PyGlobals[]:=
	PyCall["globals"][]


PyAlias@PyHasAttr[args__]:=
	PyCall["hasattr"][args]


PyAlias@PyHash[arg_]:=
	PyCall["hash"][arg]


PyAlias@PyHelp[args___]:=
	PyCall["help"][args]


PyAlias@PyHex[arg_]:=
	PyCall["hex"][arg]


PyAlias@PyID[obj_]:=
	PyCall["id"][obj]


PyAlias@PyInput[args___]:=
	PyCall["input"][args]


PyAlias@PyInt[n:Except[_?NumericQ]]:=
	PyCall["int"][n];
PyAlias@PyInt[n_,b_]:=
	PyCall["int"][n,b];


PyAlias@PyIsInstance[obj_,tup_]:=
	PyCall["isinstance"][obj,tup]


PyAlias@PyIsSubclass[obj_,class_]:=
	PyCall["issubclass"][obj,class]


PyAlias@PyIter[iter__]:=
	PyCall["iter"][iter]


PyAlias@PyLen[arg_]:=
	PyCall["len"][arg]


PyAlias@PyList[l:Except[_List]]:=
	PyCall["list"][l]


PyAlias@PyLocals[]:=
	PyCall["locals"][]


PyAlias@PyMap[f_,iters__]:=
	PyCall["map"][f,iters]


PyAlias@PyMax[iter_,key___]:=
	PyCall["max"][iter,key]


PyAlias@PyMemoryView[obj_]:=
	PyCall["memoryview"][obj]


PyAlias@PyMin[iter_,keys___]:=
	PyCall["min"][iter,keys]


PyAlias@PyNext[obj_,def___]:=
	PyCall["next"][obj,def]


PyAlias@PyObject[]:=
	PyCall["object"][]


PyAlias@PyOct[arg_]:=
	PyCall["oct"][arg]


PyAlias@PyOpen[f_,args___]:=
	PyCall["open"][f,args]


PyAlias@PyOrd[c_]:=
	PyCall["ord"][c]


PyAlias@PyPow[x_,y_,z___]:=
	PyCall["pow"][x,y,z]


PyAlias@PyPrint[args__]:=
	PyCall["print"][args];
PyAlias@PyPrint:=
	"print";


PyAlias@PyProperty[args___]:=
	PyCall["property"][args]


PyAlias@PyRange[sp_,ec___]:=
	If[AllTrue[{sp,ec},IntegerQ],
		PyCall["range"][sp,ec],
		PyImportSow["numpy"];
		PyCall["list"]@
			PyCall["numpy.arange"][sp,ec]
		]


PyAlias@PyRepr[obj_]:=
	PyCall["repr"][obj]


PyAlias@PyReversed[iter_]:=
	PyCall["reversed"][iter]


PyAlias@PyRound[n_,d___]:=
	PyCall["round"][n,d]


PyAlias@PySet[]:=
	PyCall["set"][];
PyAlias@PySet[i:Except[_List]]:=
	PyCall["set"][i];


PyAlias@PySetAttr[args__]:=
	PyCall["setattr"][args]


PyAlias@PySorted[i_,keys___]:=
	PyCall["sorted"][i,keys]


PyAlias@PyStaticMethod[f_]:=
	PyCall["staticmethod"][f]


PyAlias@PyStr[args___]:=
	PyCall["str"][args]


PyAlias@PySum[args__]:=
	PyCall["sum"][args]


PyAlias@PySuper[args___]:=
	PyCall["super"][args]


PyAlias@PyTuple[]:=
	PyCall["tuple"][];
	PyAlias@PyTuple[i:Except[_List]]:=
	PyCall["tuple"][i];


PyAlias@PyType[args__]:=
	PyCall["type"][args]


PyAlias@PyVars[args___]:=
	PyCall["vars"][args]


PyAlias@PyZip[args__]:=
	PyCall["zip"][args]


PyAlias@
	PySin[q_]:=
		(
			ToPython@PyImportSow["math"];
			PyCall[PyDot["math","sin"]][q]
			)


PyAlias@
	PyCos[q_]:=
		(
			ToPython@PyImportSow["math"];
			PyCall[PyDot["math","cos"]][q]
			)


PyAlias@
	PyTan[q_]:=
		(
			ToPython@PyImportSow["math"];
			PyCall[PyDot["math","tan"]][q]
			)


PyAlias@
	PyArcTan[q__]:=
		(
			PyImportSow["math"];
			PyCall[PyDot["math","arctan"]][q]
			)


PyAlias@
	PyArcCos[q__]:=
		(
			PyImportSow["math"];
			PyCall[PyDot["math","arccos"]][q]
			)


PyAlias@
	PyArcSin[q__]:=
		(
			PyImportSow["math"];
			PyCall[PyDot["math","arcsin"]][q]
			)


PyAlias@
PySqrt[a_]:=
	(
		PyImportSow["math"];
		PyCall[PyDot["math","sqrt"]][a]
		)


(* ::Subsection:: *)
(*Extended Constructs*)



PyAlias@
	PyImportAs[import_,as_]:=
		PyRow[{PyImport[import],PyAs[as]}," "];
PyAlias@
	PyFromImport[from_,import_]:=
		PyRow[{PyFrom[from],PyImport[Replace[import,All->"*"]]}," "];
PyAlias@
	PyFromImportAs[from_,import_,as_]:=
		PyRow[{PyFrom[from],PyImport[import],PyAs[as]}," "];


PyAlias@
	PyIfElse[test_][if_,else_]:=
		PyColumn[
			PyIf[test],
			PyElse[else]
			];


PyAlias@
	PyWhich[pairs__]:=
		With[{p=Partition[pairs,2]},
			PyColumn@Flatten@{
				PyIf[p[[1,1]]][p[[1,2]]],
				If[#[[1]]//TrueQ,
					PyElse[#[[2]]],
					PyElIf[#[[1]]][#[[2]]]
					]&/@p[[2;;]]
				}
			]


PyAlias@PyForIn[var_,iter_][val:{__}]:=
	PyFor[PyIn[var,iter]][val];
PyAlias@PyForIn[var_,iter_][val:Except[_List]]:=
	PyForIn[var,iter][{val}];
PyAlias@PyForIn[var_,iter_][val_,vals__]:=
	PyForIn[var,iter][{val,vals}];


PyAlias@
	PyMagic[s_String]:=
		"__"<>s<>"__";
PyAlias@
	PyMagic[s_String][a___]:=
		PyCall[PyMagic[s]][a];


PyAlias@
	PyPrivate[s_String]:=
		"__"<>s;
PyAlias@
	PyPrivate[s_String][a___]:=
		PyCall[PyPrivate[s]][a];


PyAlias@PyConditional[test_][if_,else_]:=
	PyRow[{if,"if",test,"else",else}," "];


PyAlias[PyListComprehension[expr_,iter:Except[_List|_Integer]]]:=
	PyRow[{"[",expr,iter,"]"}," "];
PyAlias[PyListComprehension[expr_,{var_,iter:Except[_Integer]}]]:=
	PyListComprehension[expr,PyRow[{"for",var,"in",iter}," "]]
PyAlias[PyListComprehension[expr_,{var_,nspec__Integer}]]:=
	PyListComprehension[expr,PyRow[{"for",var,"in",PyRange[nspec]}," "]];
PyAlias[PyListComprehension[expr_,n_Integer]]:=
	PyListComprehension[expr,{"_iter_counter",n}]


PyAlias[PyGenerator[expr_,iter:Except[_List|_Integer]]]:=
	PyRow[{"(",expr,iter,")"}," "];
PyAlias[PyGenerator[expr_,{var_,iter:Except[_Integer]}]]:=
	PyGenerator[expr,PyRow[{"for",var,"in",iter}," "]]
PyAlias[PyGenerator[expr_,{var_,nspec__Integer}]]:=
	PyGenerator[expr,PyRow[{"for",var,"in",PyRange[nspec]}," "]];
PyAlias[PyGenerator[expr_,n_Integer]]:=
	PyGenerator[expr,{"itercounter",n}]


PyAlias[PyDictComprehension[expr_,iter:Except[_List|_Integer]]]:=
	PyRow[{"{",Replace[expr,{
		Rule[a_,b_]:>
			PyRule[a,b,":"],
		RuleDelayed[a_,b_]:>
			PyRule[a:>b,":"]
		}],iter,"}"}," "];
PyAlias[PyDictComprehension[expr_,{var_,iter:Except[_Integer]}]]:=
	PyDictComprehension[expr,PyRow[{"for",var,"in",iter}," "]]
PyAlias[PyDictComprehension[expr_,{var_,nspec__Integer}]]:=
	PyDictComprehension[expr,PyRow[{"for",var,"in",PyRange[nspec]}," "]];
PyAlias[PyDictComprehension[expr_,n_Integer]]:=
	PyDictComprehension[expr,{"itercounter",n}]


PyAlias@
	PyIfMain[expr_]:=
		PyIf["__name__"~PyEqual~PyString["__main__"]][expr];


PyAlias@
$PySysPath:=
	(
		PyImportSow["sys"];
		PyDot["sys","path"]
		)


PyAlias@
PySysPathInsert[o_:0,p_]:=
	(
		PyImportSow["sys"];
		PyCall[PyDot[PyDot["sys","path"],"insert"]][o,p]
		)


(* ::Subsection:: *)
(*Mathematica Constructs*)



PyAlias@
	PyModule[e___,ifm_]:=
		PyColumn[e,PyIfMain[ifm]]


PyAlias@
	PySubdivide[min_,max_,n_]:=
		PyRange[min,max,(max-min)/n]


$PyFromSphericalCoordinates=
	PyLambda[{"r","q","j"}]@
		{ 
			{
				PyMultiply["r",PyCos["j"],PySin["q"]],
				PyMultiply["r",PySin["j"],PySin["q"]],
				PyMultiply["r",PyCos["q"]]
				}
			};


PyAlias@
PyFromSphericalCoordinates[{r_,q_,j_}]:=
	PyCall[$PyFromSphericalCoordinates][r,q,j];
PyAlias@
PyFromSphericalCoordinates[e_]:=
	PyCall[$PyFromSphericalCoordinates][e]


$PyToSphericalCoordinates=
	PyLambda[{"x","y","z"}]@
	{
		{
			PySqrt[
				PyPlus[PyPower["x",2],PyPower["y",2],PyPower["z",2]]
				],
			PyArcTan["z",
				PySqrt[PyPlus[PyPower["x",2],PyPower["y",2]]]
				],
			PyArcTan["x","y"]
			}
		}


PyAlias@
PyToSphericalCoordinates[{x_,y_,z_}]:=
	PyCall[$PyToSphericalCoordinates][x,y,z];
PyToSphericalCoordinates[e_]:=
	PyCall[$PyToSphericalCoordinates][e]


PyAlias@
PyStringToStream[s_]:=
	(
		PyImportSow["StringIO"];
		PyDot["StringIO","StringIO"][s]
		)


PyAlias@
PyMemberQ[obj_,thing_]:=
	PyIn[thing,obj]


PyAlias@
PyDo[f_,vals_Integer]:=
	PyFor[PyIn["_iteration_var_",PyRange[vals]]][PyColumn[{f, None}]];
PyAlias@
PyDo[f_,{var_,vals:Except[_Integer]}]:=
	PyFor[PyIn[var,vals]][PyColumn[{f, None}]];
PyAlias@
PyDo[f_,{var_,vals_Integer}]:=
	PyFor[PyIn[var,PyRange[vals]]][PyColumn[{f, None}]];
PyAlias@
PyDo[f_,{var_,start_,stop_}]:=
	PyFor[PyIn[var,PyRange[start,stop]]][PyColumn[{f, None}]];
PyAlias@
PyDo[f_,{var_,start_,stop_,step_}]:=
	PyFor[PyIn[var,PyRange[start,stop]]][PyColumn[{f, None}]]


PyAlias@
PyScan[f_,vals_]:=
	PyFor[PyIn["_iteration_var",vals]][f["_iteration_var"]];


PyAlias@
PyFunction[f_]:=
	With[{anonyF=
		Reap@
		Replace[f,
			HoldPattern[tmp:(Function|PyFunction)[__]]:>(Sow[tmp];Hash[tmp]),
			\[Infinity],
			Heads->True
			]
		},
		With[{vars=
			Replace[anonyF[[1]],{
				Slot[n_]:>
					{Slot[n]->"_lambda_var_"<>ToString[n]},
				_:>DeleteDuplicates@
					Cases[anonyF[[1]], 
						Slot[n_]:>(Slot[n]->"_lambda_var_"<>ToString[n]),
						\[Infinity]]
				}]
			},
			PyLambda[Values@vars]@
				If[ListQ@anonyF[[1]],{anonyF[[1]]},anonyF[[1]]]/.
					Join[
						vars,
						Map[Hash[#]->#&,Flatten@anonyF[[2]]]
						]
			]
		];
PyAlias@
PyFunction[vars_,f_,___]:=
	PyLambda[vars]@
		If[ListQ@f,{f},f];


PyAlias@
PyMapIndexed[f_,l_]:=
	PyListComprehension[
		f["_iteration_val","_iteration_index"],
		{{"_iteration_val","_iteration_index"},PyEnumerate[l]}
		]


PyAlias@
PyScanIndexed[f_,l_]:=
	PyFor[PyIn[{"_iteration_val","_iteration_index"},PyEnumerate[l]]][
		f["_iteration_val","_iteration_index"]
		]


PyAlias@PyStringRiffle[l_,x_]:=
	PyCall[PyDot[PyString[x],"join"]][l]


(* ::Subsection:: *)
(*Fallbacks*)



PyAlias@(struct_?SymbolicPythonQ)[a___]:=
	PyCall[struct][a];
PyAlias@(struct_?SymbolicPythonQ)[a___][b___]:=
	Fold[
		PyCall[#][Sequence@@#2]&,
		{{a},{b}}
		];
PyAlias@(struct_?SymbolicPythonQ)[a___][b___][c___]:=
	Fold[
		PyCall[#][Sequence@@#2]&,
		{{a},{b},{c}}
		];
PyAlias@(struct_?SymbolicPythonQ)[a___][b___][c___][d___]:=
	Fold[
		PyCall[#][Sequence@@#2]&,
		{{a},{b},{c},{d}}
		]


(* ::Subsection:: *)
(*Usage*)



$PySymbolsContext=$Context;


$PyLangTranslations=Dispatch@{

	Equal->PyEqual,
	Rule->Rule (* Just protecting it from later replacement *),
	SameQ->PyIs,
	Less->PyLess,
	LessEqual->PyLessEqual,
	Greater->PyGreater,
	GreaterEqual->PyGreaterEqual,
	And->PyAnd,
	Or->PyOr,
	Not->PyNot,
	AllTrue->PyAll,
	AnyTrue->PyAny,
	Min->PyMin,
	Max->PyMax,
	Plus->PyPlus,
	Subtract->PyMinus,
	Times->PyMultiply,
	Divide->PyDivide,
	Sqrt->PySqrt,
	Power[z_,1/2]:>PySqrt[z],
	Power->PyPower,
	AddTo->PyAddTo,
	SubtractFrom->PySubtractFrom,
	TimesBy->PyMultiplyBy,
	DivideBy->PyDivideBy,
	Remove->PyDel,
	CompoundExpression->PyColumn@*List,
	Dot->PyDot,
	Part->PyIndex,
	Span->PySlice,
	Print->PyPrint,
	ToString->PyStr,
	Return->PyReturn,
	Break->PyBreak,
	Assert->PyAssert,
	Which->PyWhich,
	Subdivide->PySubdivide,
	Sin->PySin,
	Cos->PyCos,
	Tan->PyTan,
	ArcSin->PyArcSin,
	ArcCos->PyArcCos,
	ArcTan->PyArcTan,
	FromSphericalCoordinates->PyFromSphericalCoordinates,
	ToSphericalCoordinates->PyToSphericalCoordinates,
	StringToStream->PyStringToStream,
	HoldPattern[$Path]->$PySysPath,
	MemberQ->PyMemberQ,
	Throw->PyRaise,
	Do->PyDo,
	Scan->PyScan,
	Function->PyFunction,
	HoldPattern@
		MapIndexed[(h:Function|PyFunction)[a___,CompoundExpression[f__,Null]],l_]:>
		PyScanIndexed[h[a,CompoundExpression[f]],l],
	MapIndexed->PyMapIndexed,
	StringRiffle->PyStringRiffle,
	StringJoin->PyPlus,
	
	HoldPattern[PyString[PyString[s__]]]:>
		PyString[s],
	HoldPattern[PyString[PyString[s_,___],sep_]]:>
		PyString[s,sep],
		
	HoldPattern[Verbatim[Blank][h:_String|_Symbol]]:>
		RuleCondition["_"<>Replace[Unevaluated@h,_Symbol:>SymbolName[h]],True],
	HoldPattern[Verbatim[Blank][h_]]:>
		PyRow@{"_",h},
	HoldPattern[
		(Times|PyMultiply)[
			Verbatim[BlankSequence][h_],
			Verbatim[BlankSequence][]
			]
		]:>
		PyMagic[h],
	HoldPattern[
		(Times|PyMultiply)[
			Verbatim[BlankSequence][h_],
			Verbatim[BlankSequence][][e___]
			]
		]:>
		PyMagic[h][e],
	HoldPattern[Verbatim[BlankSequence][h_]]:>
		PyPrivate[h],
	HoldPattern[Set[var_,val_]]:>
		PyAssign[var,val],
	HoldPattern[SetDelayed[
		(p_PyDecorator)[pat_],
		val_
		]]:>
		p[SetDelayed[pat,val]],
	HoldPattern[SetDelayed[
		(var:_String|_Symbol?(
			Function[Null,
			Not@MatchQ[Context[#],$PySymbolsContext|"System`"],
			HoldFirst])|
			_PyMagic|_PySymbol)[pats__],val_]]:> 
		PyDef[var,
			Replace[{pats},{
				Verbatim[Pattern][p_,_]:>
					p,
				Verbatim[Optional[p_,v_]]:>
					Replace[p,Verbatim[Pattern][p2_,_]:>p2]->v
				}]][val],
	HoldPattern@Module[{vars___},CompoundExpression[e___,r_]]:>
		PyLambda[vars][{e,r}],
	HoldPattern@Module[{vars___},e_]:>
		PyLambda[vars][e],
	HoldPattern[s_Symbol?(Function[Null,Context[#]===$Context,HoldFirst])]:>
		RuleCondition[SymbolName@Unevaluated[s],True],
	HoldPattern[s_String[args___]]:>
		PyCall[s][args],
		
	HoldPattern@Increment[var_]:>
		PyAddTo[var,1],
	HoldPattern@Decrement[var_]:>
		PySubtractFrom[var,1],
	
	HoldPattern@If[test_,if_]:>
		PyIf[test][if],
	HoldPattern@If[test_,if_,else_]:>
		PyIfElse[test][if,else],
		
	HoldPattern[Import[f_->v_->a_]]:>
		PyFromImportAs[f,v,a],
	HoldPattern[Import[f:Except[_Rule|_Dot|_PyDot]->v_]]:>
		PyImportAs[f,v],
	HoldPattern[Import[(Dot|PyDot)[f_,v_]]]:>
		PyFromImport[f,v],
	HoldPattern[Import[(Dot|PyDot)[f_,v_]->a_]]:>
		PyFromImportAs[f,v,a],
	HoldPattern[Import[f:Except[_Rule|_Dot|_PyDot]]]:>
		PyImport[f],
		
	HoldPattern[For[init_,test_,inc_,do_]]:>
		(init;While[test,do;inc]),
	HoldPattern[While[test_,do_]]:>
		PyWhile[test][do],
	HoldPattern@Map[f_,i_]:>
		PyList@PyMap[f,i],
	HoldPattern@MapThread[f_,{i__}]:>
		PyList@PyMap[f,i],
		
	HoldPattern[Table[expr_,spec_]]:>
		PyListComprehension[expr,spec],
	
	HoldPattern[Range[spec___]]:>
		PyRange[spec],
		
	HoldPattern[Insert[x_,v_,p_]]:>
		PyDot[x,"insert"][p,v],
	HoldPattern[Append[x_,v_]]:>
		PyDot[x,"append"][v]
		
	};


$PyLangTranslationSymbols=
	Replace[Keys[Normal@$PyLangTranslations],
		{
			Verbatim[HoldPattern][s_[___]]:>s,
			s_Symbol:>s,
			_->Nothing
			},
		1]


ToSymbolicPython[symbols:{___Symbol}:{},expr_]:=
	With[{syms=
		Replace[
			Thread@Hold[symbols],
			Hold[s_]:>(HoldPattern[s]->PySymbol[SymbolName[Unevaluated@s]]),
			1],
		trfPat=
			MatchQ[Alternatives@@$PyLangTranslationSymbols],
		ptCont=
			$PackageName<>"`*"
		},
		ReleaseHold[
			ReplaceRepeated[
				Hold[expr]/.
					Join[syms,
						{
							p_PyString:>p (* Protects the inner string from further replacement *),
							HoldPattern[String[s_]]:>PyString[s],
							s_String?(Not@StringMatchQ[#,(WordCharacter|"_"|".")..]&):>
								RuleCondition[
									PyString[s,
										If[Length@StringSplit[s,EndOfLine]>1,
											"'''",
											"'"
											]
										],
									True
									]
							}
						]/.
					s_Symbol?(
						Function[Null, 
							!StringMatchQ[Context[#],ptCont]&&
							!trfPat[#]&&(
							System`Private`HasDownCodeQ[#]||
							System`Private`HasUpCodeQ[#]||
							!StringMatchQ[Context[#],"System`*"]
							),
							HoldAllComplete
							]):>
						PySymbol[s],
				$PyLangTranslations
				]
			]
		];
ToSymbolicPython~SetAttributes~HoldAll;


(*Needs["MyTools`"];*)


(*$PyProc=None;
$PyBin="python3";
$PyDir="/usr/local/bin";
PythonRun::err=ProcessRun::err;
PythonRun[s_String?(Not@*FileExistsQ)]:=
	If[ProcessStatus@$PyProc=!="Running",
		With[{f=CreateFile@FileNameJoin@{$TemporaryDirectory,"pylink_in.py"}},
			OpenWrite@f;
			WriteString[f,s];
			Close@f;
			(DeleteFile@f;#)&@PythonRun[f]
			],
		WriteString[$PyProc,s];
		WriteString[$PyProc,"\n"];
		Pause[.1];
		<|
			"StandardOutput"->
				ReadString[ProcessConnection[$PyProc,"StandardOutput"],EndOfBuffer],
			"StandardError"->
				ReadString[ProcessConnection[$PyProc,"StandardError"],EndOfBuffer]
			|>
		];
PythonRun[f_String?FileExistsQ]:=
	ProcessRun[{$PyBin,f},PythonRun::err,
		ProcessEnvironment\[Rule]<|
			"PATH"->
				StringJoin@{$PyDir,":",Environment["PATH"]}
			|>];
PythonRun[e:Except[_String]]:=
	Replace[ToPython@ToSymbolicPython@e,{
		s_String\[RuleDelayed]PythonRun[s],
		_\[RuleDelayed]$Failed
		}];
PythonRun~SetAttributes~HoldFirst*)


(*PythonStart[]:=(
	$PyProc=
		StartProcess[{$PyBin(*,"-i"*)},ProcessEnvironment\[Rule]<|
			"PATH"->
				StringJoin@{$PyDir,":",Environment["PATH"]}
			|>];
	ReadString[ProcessConnection[$PyProc,"StandardError"],EndOfBuffer];
	ReadString[$PyProc,EndOfBuffer];
	$PyProc
	);
PythonKill[]:=(
	KillProcess@$PyProc;
	$PyProc=None
	);*)


End[];



