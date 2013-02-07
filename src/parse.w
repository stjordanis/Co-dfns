\def\title{CO-DFNS PARSER (Version 0.1)}
\def\topofcontents{\null\vfill
  \centerline{\titlefont Co-Dfns Parser}
  \vskip 15pt
  \centerline{(Version 0.1)}
  \vfill}
\def\botofcontents{\vfill
\noindent
Copyright $\copyright$ 2013 Aaron W. Hsu $\.{arcfide@@sacrideo.us}$
\smallskip\noindent
All rights reserved.
}

% These are some helpers for handling some of the apl characters.
\def\aa{\alpha\alpha}
\def\ww{\omega\omega}

@* Parsing Co-Dfns. The Co-Dfns language is a rather difficult one to 
parse effectively. While most of the language is trivial, the language
has one or two parts that are inherently ambiguous if you do not already
know the variable references are functions or values. This document
describes the parser for Co-Dfns. Most of the parser is designed 
around the PEG grammar given in {\tt grammar.peg}, which is used to 
generate a recursive decent, backtracking parser using the {\tt peg(1)}
program. This file sets the surrounding context for this parser 
and configures its settings so that it is usable in the rest of the 
Co-Dfns ecosystem.

At the moment, we compile a |main()| program for doing program 
recognition. It runs the parser on the file given in the command
line until no more content is parsable, and then exits.

@p
#include <stdio.h>
#include <stdlib.h>

@<Declare internal structures@>@;
@<Declare prototypes...@>@;

#include "grammar.c"

@<Define stack functions@>@;
@<Define internal functions@>@;
@<Define parsing functions@>@;

void
print_usage_exit(char *progname)
{
	printf("%s : [filename]\n", progname);
	exit(EXIT_FAILURE);
}

int
main(int argc, char *argv[])
{
	yycontext ctx;
	FILE *infile;
	
	memset(&ctx, 0, sizeof(yycontext));
	init_stack(&ctx.op_seen, 50);
	
	switch(argc) {
	case 1: 
		ctx.infile = stdin; 
		break;
	case 2:
		if ((infile = fopen(argv[1], "r")) == NULL) {
			perror(argv[0]);
			exit(EXIT_FAILURE);
		}
		ctx.infile = infile;
		break;
	default:
		print_usage_exit(argv[0]);
	}
	
	while(parse_apl(&ctx));
	
	if (argc == 2 && fclose(infile) == EOF) {
		perror(argv[0]);
		exit(EXIT_FAILURE);
	}
	
	return EXIT_SUCCESS;
}

@ The parser generated by {\tt peg} needs to have a few things customized 
to make things nicer to program with. These settings are made here. In 
particular, the main parser name should be |parse_apl| rather than 
|yyparse| and the parser should use a local context. 

@d YYPARSE parse_apl
@d YY_CTX_LOCAL

@ There are a number of additional fields that we use to deal with the 
extra information that we need when parsing. These fields are members 
of the local context that we setup above.

@d YY_CTX_MEMBERS 
	FILE *infile; /* The input file from which we are reading */
	struct stack op_seen; /* Track whether we have seen operator variables */
@d OPSEEN_PTR(ctx) (&ctx->op_seen)
	
@ The default parser uses |YY_INPUT(buf, result, max_size)| to read
input in, but this reads from standard input by default, and we would
like to control the input form of the compiler. To do this, we redefine 
this macro to read from the |ctx->infile| which is a member that we 
set to be the input |FILE *| pointer.

@d YY_INPUT(buf, result, max_size)
{
	int yyc = fgetc(ctx->infile);
	result = (EOF == yyc) ? 0 : (*(buf) = yyc, 1);
}

@* Parsing User-defined Operators. Parsing of operators defined by the user 
gets a little interesting. In particular, in Co-Dfns, an user defined function is 
either an operator or a function, but not both. One can determine statically 
at parse time whether a given procedure is a function or an operator by 
examining the occurences of $\aa$ or $\ww$ that appear in the body of 
the local scope. It's important that only those variables considered in 
the immediate scope matter. A nested operator inside of an user defined 
function should not cause that function to be treated as an operator.
However, if a $\ww$ is found inside of the function body, then it is a 
dyadic operator. If no $\ww$ occurs in the body but an occurence of 
$\aa$ is found, then it must be a monadic operator. If on the other hand, 
neither of these two variables appears, then the user-defined entity must 
be a function.

One approach to handling this in the PEG grammar would be to have a single
non-terminal for Functions and another one for operators. We could then create 
a number of duplicate subordinate non-terminals that mirrored on another for 
each of the syntaxes, since they are basically the same. This is ugly, because 
the syntax for an operator and a function is the exact same excepting the 
occurences of $\aa$ or $\ww$. 

To make this a little cleaner, we will instead use the |op_seen| field of the 
peg context declared above. This a stack where each element in the stack 
represents one additional level of nesting for user-defined functions and 
operators. At each level we have three different cases. Firstly, we could 
have no operator variables, indicated by the value |UD_FUNC|. We could then 
have a monadic operator, indicated by the value |UD_MONA|. Finally, 
we have a dyadic operator, indicated by the value |UD_DYAD|. Each element 
in the stack is one of these three values. During parsing when we 
encounter a new user-defined function or operator, we push another element 
onto the stack and initialize it to |UD_FUNC|. When we encounter any operator 
variable, then we promote this value upwards to either |UD_MONA| or |UD_DYAD|. 
We never downgrade from |UD_DYAD| to either |UD_MONA| or |UD_FUNC|, and 
we similarly never downgrade from |UD_MONA| to |UD_FUNC|. When we 
encounter the corresponding closing brace of an user-defined function or 
operator, then we can check the value of the top of the stack to determine 
whether we have a function or an operator.

@d UD_FUNC 0
@d UD_MONA 1
@d UD_DYAD 2

@ To support this approach to parsing, we define |enter_ud| that is to be 
called on each entrance to an user-defined function or operator. This will 
do all of the initialization and make sure that things are pushed onto the
stack as appropriate. It takes the operator status stack as input.

@<Define parsing functions@>=
int
enter_ud(struct stack *stk)
{
	int val = 0;
	int stkr, envr;
	
	stkr = PUSH(stk, &val, int);
	
	return !(stkr || envr);
}

@ @<Declare prototypes...@>=
int enter_ud(struct stack *);

@ When we have seen what might be a closing brace to a function or an 
operator, then we need to check whether it is an operator or what. We also 
need to make sure that we pop the stack appropriately. Thus, we define 
three predicates that will return true or false. For each predicate, we will
only pop the stack if we encounter what we expect and return true.

@d UD_PRED(name, errstr, type)
int name(struct stack *stk)
{
	int val;
	
	if (POP(stk, &val, int)) {
		fprintf(stderr, "%s: unexpected empty stack\n", errstr);
		exit(EXIT_FAILURE);
	}
	
	return (val == type);
}

@<Define parsing functions@>=
UD_PRED(is_ud_func, "is_ud_func", UD_FUNC)@;
UD_PRED(is_ud_mona, "is_ud_mona", UD_MONA)@;
UD_PRED(is_ud_dyad, "is_ud_dyad", UD_DYAD)@;

@ Finally, these functions need to be included in the protypes since they 
are used as a part of the PEG grammar.

@<Declare prototypes used in the grammar@>=
int is_ud_func(struct stack *);
int is_ud_mona(struct stack *);
int is_ud_dyad(struct stack *);

@ When we encounter an operator variable ($\aa$ or $\ww$) then we need 
to set the stack variable appropriately. We do this by popping the current
one and putting the right one back in. The right one is the max of the current 
value and the value of the operator that we have seen.

@d SEEN_OP_VAR(name, errstr, type)
int name(struct stack *stk)
{
	int val;
	
	if(POP(stk, &val, int)) {
		fprintf(stderr, "%s: unexpected empty stack\n", errstr);
		exit(EXIT_FAILURE);
	}
	
	val = val < type ? type : val;
	PUSH(stk, &val, int);
	
	return 0;
}

@<Define parsing functions@>=
SEEN_OP_VAR(seen_mona_var, "seen_mona_var", UD_MONA)@;
SEEN_OP_VAR(seen_dyad_var, "seen_dyad_var", UD_DYAD)@;

@ And of course, things need to go into the prototype.

@<Declare prototypes...@>=
int seen_mona_var(struct stack *);
int seen_dyad_var(struct stack *);

@* Dealing with function variables and application. 
The most annoying thing about parsing APL is the ambiguity that you get 
when dealing with variables that are bound to functions. Consider the 
following program fragment:

\medskip{\tt A B C}\medskip

\noindent In the above, the parsing of this depends on the values of 
the various variables. If they are all values, then this is an array 
or value. If C is a function then if this were considered as a single 
statement, we would have an error on our hands. If on the other 
hand C is a value, then we have many possible parsings that we 
could encounter depending on whether B is a function, value, or 
operator, and whether A is a value or function. 

In order to deal with this, we actually have to track the value 
versus function versus operator status of the various variables 
for each user-defined function. We will achieve this by using a variable
environment that tracks the types of the variable. For this we need 
a variable/type pair structure. The type variables will be one 
of |VT_VAL|, |VT_FUN|, or |VT_OPR|. These names have their obvious 
meaning. There is one additional value |VT_FRM| that represents a 
function ``frame.'' When we enter a new function, we enter a new 
scope, and when we leave that function, all of the variables that were 
in that scope are no longer visible. In order to make it easy to get 
rid of all of those variables introduced in that scope, entering a 
new function is marked by pushing a |VT_FRM| value onto the stack.
We also include a type of |VT_UND| which can be used to indicate that 
a given variable is undefined. However, we do not expect any variables 
pushed onto an environment to have this value. This is something that 
some procedures may return to help analysis, but one should not push 
the |VT_UND| value onto an environment.

@<Declare internal structures@>=
enum var_type { VT_FRM, VT_UND, VT_VAL, VT_FUN, VT_OPR };
struct vt_pair {
	enum var_type type;
	char var_name[];
};

@ The structure that we use to support the vt pairs is called a 
|struct vt_env| and it basically is a |struct stack|. However, we attach a 
few more fields to track a second memory pool which stores our 
|struct vt_pair| objects. 

@<Declare internal structures@>=
struct vt_env {
	void *end;
	void *current;
	void *start;
	void *pend;
	void *curvtp;
	void *pstart;
};

@ We have to do a similar sort of initialization as with |struct stack| 
objects. The initialization uses |init_stack| but it needs to do some 
book-keeping of its own. In particular, we pass in the rough number of 
variables that we want to support instead of the number of bytes to 
allocate. To make our life easier, we take advantage of the fact that 
we have laid out our structures in the exact same way as two 
stacks, and that we initialize the pair stack in the same way that 
we initialize a normal stack.

@<Define internal functions@>=
int 
init_vtenv(struct vt_env *env, int count)
{
	size_t vtpsize, stksize;
	
	vtpsize = (sizeof(struct vt_pair) + 12) * count;
	stksize = sizeof(struct vt_pair *) * count;
	
	if (init_stack((struct stack *)env, stksize)) {
		fprintf(stderr, "init_vtenv: bad stack init\n");
		return 1;
	}
	
	if (init_stack((struct stack *)&env->pend, vtpsize)) {
		fprintf(stderr, "init_vtenv: bad pair stack init\n");
		return 1;
	}
	
	return 0;
}

@ During parsing, when we encounter a definition or variable binding, 
we will push the type of that binding onto the variable environment. 
To do this, we will use the |push_var| function, which takes a character 
string of the variable name and the type of variable and pushes onto 
the stack. When we enter a function, we need to push a frame separator onto 
the stack, which is done in the same way that we push a normal variable 
onto the stack, except that we give the |VT_FRM| value and |""| to 
the variable name.

@<Define parsing functions@>=
int 
push_var(struct vt_env *env, char *var, enum var_type typ)
{
	size_t siz;
	struct vt_pair *vp;
	
	siz = sizeof(struct vt_pair) + strlen(var) + 1;
	
	while (siz > VTENV_FREE(env)) {
		if (resize_vtenv(env, VTENV_SIZE(env) * 1.5)) {
			fprintf(stderr, "failed to resize vt_env\n");
			exit(EXIT_FAILURE);
		}
	}
	
	vp = env->curvtp;
	vp->type = typ;
	strcpy(vp->var_name, var);
	env->curvtp = ((char *)env->curvtp) + siz;
	return PUSH((struct stack *)env, &vp, struct vt_pair *);
}

@ @<Declare prototypes...@>=
int push_var(struct vt_env *, char *, enum var_type);

@ The |VTENV_FREE| AND |VTENV_SIZE| macros work very similarly 
to the equivalent macros for stacks, except that they work on the 
fields of the environment and set of |struct vt_pair| objects rather 
than the stack itself.

@d VTENV_FREE(env) ((char *)(env)->pend - (char *)(env)->curvtp)
@d VTENV_SIZE(env) ((char *)(env)->pend - (char *)(env)->pstart)

@ We have an equivalent |resize_vtenv| function to handle allocating 
more memory for the |struct vt_pair| objects if we need to.

@<Define internal functions@>=
int
resize_vtenv(struct vt_env *env, size_t size)
{
	size_t off;
	char *buf;
	
	buf = env->pstart;
	off = (char *) env->curvtp - (char *) env->pstart;

	if (off > size) {
		fprintf(stderr, "attempting to resize below current stack pointer\n");
		return 1;
	}
	
	if ((buf = realloc(buf, size)) == NULL) {
		perror("resize_vtenv");
		return 1;
	}
	
	env->pend = buf + size;
	env->curvtp = buf + off;
	env->pstart = buf;
	
	return 0;
}

@ When finishing parsing a function, it is important to pop off all of the 
values that the function may have introduced into the environment, as 
those variables will no longer be in scope after parsing of that function 
is done. The function |clear_frame| takes an environment and will clear 
from the environment all of the variables up to and including the first 
frame separator that was encountered. This function should be called 
whenever the end of a function is being parsed. Since |clear_frame| 
may be called in an expression context, we return zero from this 
function.

@<Define parsing functions@>=
int
clear_frame(struct vt_env *env)
{
	enum var_type type;
	char *name;
	
	while (!pop_var(env, &name, &type) && type != VT_FRM);
	return 0;
}

@ @<Declare prototypes...@>=
int clear_frame(struct vt_env *);

@ The whole reason for having the environment around when parsing is
so that we can ask whether a given variable is bound to a function, 
variable, or operator. To do this, use the |lookup_var| function provided 
here, which will take an environment and a character string of the variable 
name to examine. The function will return an |enum var_type| indicating 
the type of the variable if it is found, or |VT_UND| if the variable is 
not found in the environment. This function uses the |pop_var| on a temporary
stack that shares the same memory pool as the stack we are given. 
This allows us to use the destructive |pop_var| operation without having 
to worry about messing up the pointers in the original environment. 
This works because popping does not need to reallocate or change the 
memory pool at all, and simply needs to adjust some pointers in the 
main |struct vt_env| structure.

@<Define parsing functions@>=
enum var_type
lookup_var(struct vt_env *env, const char *name)
{
	enum var_type type;
	char *env_name;
	struct vt_env tmp;
	
	memcpy(&tmp, env, sizeof(struct vt_env));
	
	while (!pop_var(&tmp, &env_name, &type))
		if (!strcmp(name, env_name))
			return type;
	
	return VT_UND;
}

@ Popping values from the environment list must be treated as a lower 
level operating than just working with a normal stack, where it is one 
of the fundamental operations. We have a primitive for popping the stack 
specifically to allow for getting at a variable and its type, but we do 
not expect these things to persist. That is because the higher level 
operations we describe above which are based on popping represent the 
main interface to an environment. As can be divined from above, the 
|pop_var(env, name_dst, type_dst)| takes an environment along with two 
placeholders for the name and type of the value popped. It will return 
zero on success and a non-zero value if there are no variables to pop.

@<Define internal functions@>=
int
pop_var(struct vt_env *env, char **name, enum var_type *type)
{
	struct vt_pair *vtp;
	
	if (POP((struct stack *)env, &vtp, struct vt_pair *)) {
		fprintf(stderr, "pop_var: failed to pop stack\n");
		return 1;
	}
	
	env->curvtp = vtp;
	*name = vtp->var_name;
	*type = vtp->type;
	
	return 0;
}

@* Stacks. We make use of a number of stacks when parsing. All of these
operate over data, so we have a |struct stack| structure that allows us to 
work with them in a single interface. The stack is a block of memeory 
that is allocated and filled from the lower address to the higher. 
The |start| field points to the beginning of the stack and the |end| 
field to the ending edge of the block of memory. The |current| field points 
to the next unused place in the stack.

@<Declare internal structures@>=
struct stack {
	void *end;
	void *current;
	void *start;
};

@ Before a stack is used, it must be initialized. The |init_stack()| function
initializes a given stack pointer to the appropriate values and allocates 
enough space to hold a stack of elements |size| bytes in size. 
It returns 0 on success, and a non-zero integer on failure.

@<Define stack functions@>=
int
init_stack(struct stack *stk, size_t size)
{
	char *buf;
	
	if ((buf = malloc(size)) == NULL) {
		perror("init_stack");
		return 1;
	}
	
	stk->end = buf + size;
	stk->current = buf;
	stk->start = buf;
	
	return 0;
}

@ The function |resize_stack()| takes a stack and a new size and resizes it to 
the new size. It returns zero on success and a non-zero value on failure.

@<Define stack functions@>=
int
resize_stack(struct stack *stk, size_t size)
{
	size_t off;
	char *buf;
	
	buf = stk->start;
	off = (char *) stk->current - (char *) stk->start;
	
	if (off > size) {
		fprintf(stderr, "attempting to resize below current stack pointer\n");
		return 1;
	}
	
	if ((buf = realloc(buf, size)) == NULL) {
		perror("resize_stack");
		return 1;
	}
	
	stk->end = buf + size;
	stk->current = buf + off;
	stk->start = buf;
	
	return 0;
}

@ We can ask the size of a given stack using the |STACK_SIZE| macro. We also 
allow one to ask what the free space is for a given stack.

@d STACK_SIZE(stk) ((char *)(stk)->end - (char *)(stk)->start)
@d STACK_FREE(stk) ((char *)(stk)->end - (char *)(stk)->current)

@ A number of times we will want to do arithmetic against the fields in 
a stack, and that's more convenient if we can wrap up the casts that 
need to happen.

@d CURRENT(stk) ((char *)stk->current)

@ When pushing to the stack we need to have the size of the object that 
we are pushing, as well as the object itself. We also need to resize the 
stack if the object we want to push on the stack is bigger than the 
free space that we have left on the stack. To facilitate the convenient 
specification of the size of the object, we define a macro 
|PUSH(stack, object, type)| that will take the type of the object that we 
are pushing and use that to calculate the size, rather than requiring 
the programmer to specify this themselves. We return zero if the push
suceeds and non-zero if the push fails.

@d PUSH(stk, obj, typ) push_stack((stk), (obj), sizeof(typ))

@<Define stack functions@>=
int
push_stack(struct stack *stk, void *elm, size_t siz)
{
	while (siz > STACK_FREE(stk)) {
		if (resize_stack(stk, STACK_SIZE(stk) * 1.5)) {
			fprintf(stderr, "push: Failed to resize stack\n");
			return 1;
		}
	}
	
	memcpy(stk->current, elm, siz);
	stk->current = CURRENT(stk) + siz;
	
	return 0;
}

@ The |POP(stk, dst, typ)| does the same thing as a push but in reverse, 
copying data out of a stack and decrementing the stack pointer. 
We return a zero if the pop suceeds and a non-zero value 
if the pop fails. The resulting element is stored in the space provided.

@d POP(stk, dst, typ) pop_stack((stk), (dst), sizeof(typ))

@<Define stack functions@>=
int
pop_stack(struct stack *stk, void *dst, size_t siz)
{
	if (stk->start == stk->current)
	    return 1;
	
	stk->current = CURRENT(stk) - siz;
	memcpy(dst, stk->current, siz);

	return 0;
}

@ We can |PEEK| at a stack to get its value without actually decrementing 
the stack. We return zero if there is an element that can be peeked, and 
non-zero if there was no element to peek. If there was no element to peek, 
then the value of |dst| is not modified. This is the same as POP except 
without the decrement.

@d PEEK(stk, dst, typ) peek_stack((stk), (dst), sizeof(typ))

@<Define stack functions@>=
int
peek_stack(struct stack *stk, void *dst, size_t siz)
{
	if (stk->start == stk->current)
		return 1;

	memcpy(dst, CURRENT(stk) - siz, siz);

	return 0;
}

@ Finally we put these all into the prototypes list.

@<Declare prototypes...@>=
int push_stack(struct stack *, void *, size_t);
int pop_stack(struct stack *, void *, size_t);
int peek_stack(struct stack *, void *, size_t);


@* Index.
