%{
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>

	int yylex (void);
	int yyerror(char* s) {
		printf("%s\n", s);
		return 0;
	}
	// Stringa usata per stampare epsilon nel dot file
	static char *epsilon = "&epsilon;",
	*graphStart = "digraph { \ngraph [nodesep=\"0.75\"];\n",
	*graphEnd   = "}\n";

	// La struttura del nodo
	typedef struct Node	{
		int label;		// La label del nodo
		bool toFuse;	// Usato per stabilire se va fuso in caso di concatenazione
		bool visited;	// Usato per stabilire se già visitato
		struct Node* next[2]; // Massimo due archi uscenti
		char edgeLabel;
	} Node;

	Node *start;		// Stato iniziale 
	int count = 1;		// Counter per gli stati

	// Definiamo la posizione del nodo: iniziale, finale, di mezzo.
	typedef enum {INITIAL, FINAL, MIDDLE} Position;

	// Funzione per creare un nuovo nodo
	Node * createNode() {
		Node* node = (Node*) malloc(sizeof(Node));
		node -> label = count++; // creo nuovo nodo quindi incremento il contatore
		node -> toFuse = false;
		node -> visited = false;
		node -> edgeLabel = '\0';
		node -> next[0]	 = NULL; // set a null arco uscente
		node -> next[1]	 = NULL; // set a null arco uscente
		return node;
	}

	// Nuovo file pointer
	FILE* file;
	void addCode	 (Node * node, Position p) { 
		if (p == INITIAL) 
			fprintf(file, "\t%d[style=filled];\n", node -> label); 
		else if (p == FINAL) 
			fprintf(file, "\t%d[peripheries=2];\n", node -> label); 
		else 
			fprintf(file, "\t%d;\n", node -> label); 
	}
	void addNode	 (Node * node) { addCode(node, MIDDLE); }
	void addStart (Node * node) { addCode(node, INITIAL); }
	void addEnd	 (Node * node) { addCode(node, FINAL); }


	void addEdge(Node * node1, Node * node2, char* label)
	{
		fprintf(file, "\t%d -> %d[label=\"%s\"];\n",
		node1->label, node2->label, label);
	}

	void fuse(Node *node, int i, char* label){
		addEdge(node, node -> next[i] -> next[0], label);  // edge tra nodo e next del next
		node -> next[i] -> label = node -> next[i] -> next[0] -> label;
		node -> next[i] = node -> next[i] -> next[0]; // bypasso il nodo che non mi interessa
	}

	void visit(Node * node)
	{
		// Visitato o NULL
		if (node == NULL || node -> visited == true) return;

		if (node -> next[0] == NULL && node -> next[1] == NULL) {
			addEnd(node); // Aggiungi come stato finale
		} else if (node == start) {
			addStart(node); // Aggiungi come stato finale
		}
		else {
			addNode(node);
		}
		node -> visited = true;
		// Se ha un carattere uso quello se no imposto epsilon come label
		char* label = (node -> edgeLabel == '\0') ? epsilon : &(node -> edgeLabel);

		//Per ogni next
		int i;
		for (i = 0; i < 2; i++) {
			// Se esiste
			if (node -> next[i]) {
				// Se è da fondere
				if (node -> next[i] -> toFuse  == true) {
					fuse(node, i, label);
				}
				// Aggiungo edge tra nodo attuale e suo successivo
				else addEdge(node, node -> next[i], label);	
				visit(node -> next[i]); // visito ricorsivamente
			}
		}
	}

	void dot()
	{
		//Creo file
		file = fopen("thompson.gv", "w");
		// Metto head
		fputs(graphStart, file);
		//Visito e riepio il file
		visit(start);
		// Metto foot
		fputs(graphEnd, file);
		// Chiudo file
		fclose(file);
	}


%}

// Simboli
%token CHAR
%token PIPE STAR
%token OPEN CLOSE
%token EOL
// Tipi
%type <Value> CHAR // char
%type <NFA> RExp Exp SExp Term Fact

// Produzione Iniziale
%start RExp

%union
{
	struct {
		Node* start;
		Node* end;
	} NFA;
	char Value;
}

%%
// Parser
RExp	: 	Exp EOL {
	$$.start = $1.start;
	$$.end 	= $1.end;
	start	= $1.start;
	return 0;
};

Exp 	:	SExp
{
	$$.start = $1.start;
	$$.end 	= $1.end;
} | SExp PIPE Exp {
	// Creo nodo iniziale e nodo finale
	Node* nodeStart = createNode();
	Node* nodeEnd 	 = createNode();

	// Set nodo successivo di iniziale
	nodeStart 		-> next[0] = $1.start;
	nodeStart 		-> next[1] = $3.start;
	// Set nodo finale come successivo di S
	$1.end 	-> next[0] = nodeEnd;
	// Set nodo finale come successivo di Exp
	$3.end 	-> next[1] = nodeEnd;

	// Set nfa start/end
	$$.start = nodeStart;
	$$.end	= nodeEnd;
};

SExp	: 	Term
{
	// Set nfa start/end
	$$.start = $1.start;
	$$.end 	= $1.end;
}
|
Term SExp
{
	$1.end -> next[0] = $2.start; 	// Concatenazione
	$1.end -> toFuse = true; 		// Set to fuse
	// Set nfa start/end
	$$.start = $1.start;
	$$.end 	= $2.end;
}
;

Term	: 	Fact
{	// Set nfa start/end
	$$.start = $1.start;
	$$.end 	= $1.end;

} | Fact STAR {
	// Creo nodo iniziale e nodo finale
	Node* start = createNode();
	Node* end	 = createNode();
	//Punto next nodo iniziale a al nodo di Fact oppure direttamente a end
	start 		 -> next[0] = $1.start;
	start 		 -> next[1] = end;
	// Posso tornare indietro a start oppure posso andare a end
	$1.end 	 -> next[0] = end;
	$1.end 	 -> next[1] = $1.start;

	// Set nfa start/end
	$$.start = start;
	$$.end	= end;
};

Fact	:	OPEN Exp CLOSE {
	// Set nfa start/end
	$$.start = $2.start;
	$$.end 	= $2.end;
} |	CHAR {
	// Creo nodo iniziale e nodo finale
	Node* nodeStart = createNode();
	Node* nodeEnd	 = createNode();
	// La lable è il valore di CHAR
	nodeStart -> edgeLabel = $<Value>1;
	// Set nodo finale come successivo di iniziale
	nodeStart 		 -> next[0]	  = nodeEnd;
	// Set nfa start/end
	$$.start = nodeStart;
	$$.end	= nodeEnd;
};
%%
// Include Lex File
#include "lex.yy.c"

// Main
int main(int argc, char** argv)
{
	// Messaggio di ingresso
	printf("Regular Epression: ");
	// yyparse ritorna 0 se va a buon fine
	if (!yyparse())
	{
		// funzione per generare il codice dot
		dot();
	}
}
