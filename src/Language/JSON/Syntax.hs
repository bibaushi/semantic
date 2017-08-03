{-# LANGUAGE DataKinds, GADTs, RankNTypes, TypeOperators #-}
module Language.JSON.Syntax
  ( assignment
  , Syntax
  , Grammar
  , Term)
  where

import Control.Comonad.Cofree (Cofree(..))
import qualified Data.Syntax as Syntax
import qualified Data.Syntax.Literal as Literal
import Data.Syntax.Assignment hiding (Assignment, Error)
import qualified Data.Syntax.Assignment as Assignment
import Language.JSON.Grammar as Grammar
import qualified Term
import Data.Record
import Data.Union
import GHC.Stack

type Syntax =
  [ Literal.Array
  , Literal.Boolean
  , Literal.Hash
  , Literal.Float
  , Literal.KeyValue
  , Literal.Null
  , Literal.String
  , Literal.TextElement
  , Syntax.Error
  , []
  ]

type Term = Term.Term (Union Syntax) (Record Location)
type Assignment = HasCallStack => Assignment.Assignment (AST Grammar) Grammar Term


makeTerm :: (HasCallStack, f :< fs) => a -> f (Term.Term (Union fs) a) -> Term.Term (Union fs) a
makeTerm a f = a :< inj f

parseError :: Assignment
parseError = makeTerm <$> symbol ParseError <*> (Syntax.Error [] <$ source)

assignment :: Assignment
assignment = object <|> array <|> parseError

value :: Assignment
value = object <|> array <|> number <|> string <|> boolean <|> none <|> parseError

object :: Assignment
object = makeTerm <$> symbol Object <*> children (Literal.Hash <$> many pairs)
  where pairs = makeTerm <$> symbol Pair <*> children (Literal.KeyValue <$> (number <|> string) <*> value)

array :: Assignment
array = makeTerm <$> symbol Array <*> children (Literal.Array <$> many value)

number :: Assignment
number = makeTerm <$> symbol Number <*> (Literal.Float <$> source)

string :: Assignment
string = makeTerm <$> symbol String <*> (Literal.TextElement <$> source)

boolean :: Assignment
boolean =  makeTerm <$> symbol Grammar.True  <*> (Literal.true <$ source)
       <|> makeTerm <$> symbol Grammar.False <*> (Literal.false <$ source)

none :: Assignment
none = makeTerm <$> symbol Null <*> (Literal.Null <$ source)