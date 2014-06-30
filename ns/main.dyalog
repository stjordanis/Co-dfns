Fix←{n LK⊃Init CL (VF ⍺)WM GL CP LF AV FE LC DU KL⊃a n←PS TK VI ⍵⊣FI}
Init←{⍵(I 0 0 0)⊣'I'⎕NA'I4 ',⍵,'|Init P P P'}
VI←{~1≡≢⍴⍵:E 11 ⋄ ~∧/1≥≢∘⍴¨⍵:E 11 ⋄ ~∧/∊' '=(⊃0⍴⊂)¨⍵:E 11 ⋄ ⍵}
VF←{~(∧/∊' '=⊃0⍴⊂⍵)∧(1≡≢⍴⍵)∧(1≡≡⍵):E 11 ⋄ ⍵}
clang←'clang -O3 -Wall -pedantic -g -std=c11 -shared -fPIC -L. -o '
CL←{⍵,'.so'⊣⎕SH clang,'"',⍵,'.so" "',⍵,'.ll" -lcodfns -lm'}
LK←{n←⎕NS⍬ ⋄ 0=≢⍺:n ⋄ _←⍵∘{_←n.⍎⍵,'←''',⍵,'''##.NA''',⍺,'''' ⋄ 0}¨⊣/⍺ ⋄ n}
WM←{1=⊃r e←PrintModuleToFile ⍵ (⍺,'.ll') 1:(ErrorMessage⊃err)E 99 ⋄ ⍺}
NA←{⍺←⊢ ⋄ _←'f'⎕NA'I4 ',⍵⍵,'|',⍺⍺,' P P P' ⋄ 0≠⊃e o←EA⍬:E e ⋄ 0≠⊃e w←AP ⍵:E e 
  0≠⊃e a←AP ⍺⊣⍬:E e ⋄ 0≠e←f o a w:E e ⋄ z←ConvertArray o
  _←array_free¨o a w ⋄ _←free¨o a w ⋄ z}
EA←{#.Codfns.ffi_make_array_double 1 0 0 ⍬ ⍬}
AP←{1 3∨.=10|⎕DR ⍵:ffi_make_array_int 1(≢⍴⍵)(≢,⍵)(⍴⍵)(,⍵)
  5∨.=10|⎕DR ⍵:ffi_make_array_double 1(≢⍴⍵)(≢,⍵)(⍴⍵)(,⍵)
  E 99}
VarType←{(⍺[;1],0)[⍺[;0]⍳⊂⍵]}
Split←{' '((≠(/∘⊢)(1,(1↓(¯1⌽=))))⊂(≠(/∘⊢)⊢))⍵}
Sel←{~∨/⍺:⍵ ⋄ g←⍵⍵⍣(⊢/⍺) ⋄ 2=⍴⍺:⍺⍺⍣(⊣/⍺)g ⍵ ⋄ (¯1↓⍺)⍺⍺ g ⍵}
Prop←{(¯1⌽P∊⊂⍺)/P←(⊂''),,↑⍵[;3]}
Kids←{((⍺+⊃⍵)=0⌷⍉⍵)⊂[0]⍵}
GEPI←{{ConstInt(Int32Type)⍵ 0}¨⍵}
Eachk←{(1↑⍵)⍪⊃⍪/(⊂MtAST),(+\(⊃=⊢)0⌷⍉k)(⊂⍺⍺)⌸k←1↓⍵}
Comment←{⍺}
ByElem←{(⍺[;1]∊⊂⍵)⌿⍺}
ByDepth←{(⍵=⍺[;0])⌿⍺}
Bind←{
  (A⍳⊂'name')≥⍴A←0⌷⍉⊃0 3⌷Ast←⍵:Ast⊣(⊃0 3⌷Ast)⍪←'name'⍺
  Ast⊣((0 3)(Ni 1)⊃Ast){⍺,⍵,⍨' ' ''⊃⍨0=⍴⍺}←⍺
}
E←{⍺←⊢ ⋄ ⍺ ⎕SIGNAL ⍵}

