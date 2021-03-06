(* ::Package:: *)

(* Autogenerated Package *)

PyMExport::usage="Represents a mathematica_export inside a python run";
PyMExportParse::usage="Parses the JSON returned by a script"


PyMImport::usage="Represents a mathematica_import inside a python run";


$PyExportRules::usage=
	"A set of transformation rules to turn special data-types into python forms";


PackageScopeBlock[
	$PyExportKey;
	PyMJSONImport;
	$PyExportRules;
	]


Begin["`Private`"];


If[!ValueQ[$PyExportKey],
	$PyExportKey=CreateUUID["python-export-"]
	];


PyMJSONImport[base_]:=
	With[{
		strQ=MatchQ[Lookup[base, "ReturnType"], Except["File"|"TemporaryFile"]],
		coreFMT=
			Replace["JSON"->"RawJSON"]@
			Lookup[base, 
				"ReturnFormat", 
				Switch[Lookup[base, "ReturnType"],
					"Bytes",
						"String",
					"File"|"TemporaryFile", 
						If[FileExtension[Lookup[base,"ReturnValue"]]==="",
							"RawJSON",
							None
							],
					_,
						"RawJSON"
					]
				],
		coreData=
			Switch[Lookup[base, "ReturnType", "String"],
				"Bytes",
					Developer`DecodeBase64[
						StringTrim[Lookup[base, "ReturnValue"],"b'"|"'"]
						]
					(*If[$VersionNumber\[GreaterEqual]11.2,
						ByteArrayToString@
							ByteArray@Lookup[base, "ReturnValue"],
						With[{tmp = CreateFile[]},
							BinaryWrite[tmp, Lookup[base, "ReturnValue"]];
							Function[DeleteFile[tmp];#]@Import[tmp, "String"]
							]
						]*),
				_,
					Lookup[base, "ReturnValue"]
				]
		},
	If[coreFMT==="RawJSON",
		Quiet[
			Check[
				If[strQ,ImportString,Import][coreData,coreFMT],
				If[strQ,ImportString,Import][coreData,"JSON"],
				{
					Import::jsonhintposition,
					Import::jsonhintposandchar,
					Import::jsonnullinput,
					Import::jsonkvsep,
					Import::jsonexpendofinput,
					Import::jsontokenmismatch,
					ImportString::string,
					ImportString::bkslsh,
					Import::jsoninvalidtoken
					}
				],
			{
				Import::jsonhintposition,
				Import::jsonhintposandchar,
				Import::jsonnullinput,
				Import::jsonkvsep,
				Import::jsonexpendofinput,
				Import::jsontokenmismatch,
				ImportString::string,
				ImportString::bkslsh,
				Import::jsoninvalidtoken
				}
			],
		If[strQ,ImportString,Import][
			coreData,
			If[coreFMT===None, Sequence@@{}, coreFMT]
			]
		]
	]


PyMExportParse::wutret="Unsure how to parse \"ReturnType\" ``";
PyMExportParse[s_String]:=
	Replace[{a_}:>a]@
	StringCases[s,
		Shortest[$PyExportKey~~"\n"~~e__~~"\n"~~$PyExportKey]:>
			Replace[ImportString[e, "RawJSON"],{
				base_?OptionQ:>
					Replace[Lookup[base, "ReturnType", "String"],{
						"String"|"Bytes":>
							Quiet[
								Check[
									PyMJSONImport[base],
									Lookup[base, "ReturnValue"],
									Import::fmterr
									],
								Import::fmterr
								],
						"TemporaryFile":>
							With[{r=PyMJSONImport[base]},
								DeleteFile[Lookup[base,"ReturnValue"]];
								r
								],
						"File":>
							PyMJSONImport[base],
						else_:>
							Message[PyExportParse::wutret, else]
						}]
				}](*,
		1*)
		]


PyExportImage[i_]:=
	With[{
		r=Rasterize[i]
		},
		If[Times@@ImageDimensions[i]>5000,
			With[{f=RenameFile[#,#<>".png"]&@CreateFile[]},
				Export[f,r];
				Sow[f, "PyTemp"];
				PyMImport@<|
					"ImportValue"->PyString@f,
					"ImportFormat"->PyString@"File",
					"ImportType"->PyString@"Image"
					|>
				],
			PyMImport@<|
				"ImportValue"->PyString@ExportString[r,"PNG"],
				"ImportFormat"->PyString@"File",
				"ImportType"->PyString@"Image",
				"ImportDataFormat"->PyString@"PNG"
				|>
			]
		]


PyExportSparseArray[mat_]:=
	With[{f=RenameFile[#,#<>".mtx"]&@CreateFile[]},
		Export[f, mat];
		Sow[f, "PyTemp"];
		PyMImport@<|
			"ImportValue"->PyString@f,
			"ImportFormat"->PyString@"File",
			"ImportType"->PyString@"SparseArray"
			|>
		];


$PyExportRules=
	{
		i:_Image|_Graphics|_Graphics3D|_Image3D?ImageQ:>
			PyExportImage[i],
		s:_SparseArray?(MatrixQ[#, Internal`RealValuedNumericQ]&):>
			PyExportSparseArray[s](*,
		mat:{_List, ___}?(
			Developer`PackedArrayQ@#&&MatrixQ[#, Internal`RealValuedNumericQ]&
			):>
			PyExportSparseArray[mat]*)
		}


End[];



