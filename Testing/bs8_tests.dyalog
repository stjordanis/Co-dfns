:Namespace bs8

⍝ Test the Black Scholes benchmark for the correct output

BS←':Namespace' 'r←0.02	⋄ v←0.03' 
BS,←⊂'coeff←0.31938153 ¯0.356563782 1.781477937 ¯1.821255978 1.33027442'
BS,←⊂'CNDP2←{L←|⍵ ⋄ B←⍵≥0'
BS,←'{coeff+.×⍵*1+⍳5}¨÷1+0.2316419×L' '}'
BS,←'Run←{' 'S←0⌷⍵ ⋄ X←1⌷⍵ ⋄ T←⍺ ⋄ vsqrtT←v×T*0.5'
BS,←⊂'D1←((⍟S÷X)+(r+(v*2)÷2)×T)÷vsqrtT ⋄ D2←D1-vsqrtT'
BS,←'CNDP2 D1' '}' ':EndNamespace'

NS←⎕FIX BS

GD←{⍉↑(5+?⍵⍴25)(1+?⍵⍴100)(0.25+100÷⍨?⍵⍴1000)}

C←#.codfns.C

BS8∆GCC_TEST←{~(⊂'gcc')∊C.TEST∆COMPILERS:0⊣#.UT.expect←0
  D←⍉GD 7 ⋄ R←⊃((⎕DR 2↑D)323)⎕DR 2↑D ⋄ L←,¯1↑D ⋄ C.COMPILER←'gcc'
  _←'Scratch/bs8_gcc.c'#.codfns.C.Fix BS
  _←⎕SH './gcc Scratch/bs8_gcc'
  _←'Run_gcc'⎕NA'./Scratch/bs8_gcc.so|Run >PP <PP <PP'
  #.UT.expect←7⍴1
  0.000000000001≥|(L NS.Run R)-Run_gcc 0 L R}

BS8∆ICC_TEST←{~(⊂'icc')∊C.TEST∆COMPILERS:0⊣#.UT.expect←0
  D←⍉GD 7 ⋄ R←⊃((⎕DR 2↑D)323)⎕DR 2↑D ⋄ L←,¯1↑D ⋄ C.COMPILER←'icc'
  _←'Scratch/bs8_icc.c'#.codfns.C.Fix BS
  _←⎕SH './icc Scratch/bs8_icc'
  _←'Run_icc'⎕NA'./Scratch/bs8_icc.so|Run >PP <PP <PP'
  #.UT.expect←7⍴1
  0.000000000001≥|(L NS.Run R)-Run_icc 0 L R}

BS8∆PGI_TEST←{~(⊂'pgcc')∊C.TEST∆COMPILERS:0⊣#.UT.expect←0
  D←⍉GD 7 ⋄ R←⊃((⎕DR 2↑D)323)⎕DR 2↑D ⋄ L←,¯1↑D ⋄ C.COMPILER←'pgcc'
  _←'Scratch/bs8_pgi.c'#.codfns.C.Fix BS
  _←⎕SH './pgi Scratch/bs8_pgi'
  _←'Run_pgi'⎕NA'./Scratch/bs8_pgi.so|Run >PP <PP <PP'
  #.UT.expect←7⍴1
  0.000000000001≥|(L NS.Run R)-Run_pgi 0 L R}


:EndNamespace
