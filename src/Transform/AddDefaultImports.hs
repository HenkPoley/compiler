{-# LANGUAGE FlexibleContexts #-}
module Transform.AddDefaultImports (add) where

import Prelude hiding (maybe)
import qualified Data.Map as Map
import qualified Data.Set as Set

import qualified AST.Module as Module
import qualified AST.Variable as Var


type ImportDict =
    Map.Map Module.Name ([String], Var.Listing Var.Value)


-- DESCRIPTION OF DEFAULT IMPORTS

(==>) :: a -> b -> (a,b)
(==>) = (,)


defaultImports :: ImportDict
defaultImports =
    Map.fromList
    [ ["Basics"] ==> ([], Var.openListing)
    , ["Maybe"] ==> ([], Var.Listing [maybe] False)
    , ["Result"] ==> ([], Var.Listing [result] False)
    , ["Signal"] ==> ([], Var.Listing [signal] False)
    ]


maybe :: Var.Value
maybe =
    Var.ADT "Maybe" Var.openListing


result :: Var.Value
result =
    Var.ADT "Result" Var.openListing


signal :: Var.Value
signal =
    Var.ADT "Signal" (Var.Listing [] False)


-- ADDING DEFAULT IMPORTS TO A MODULE

add :: Bool -> Module.Module exs body -> Module.Module exs body
add noPrelude (Module.Module moduleName path exports imports decls) =
    Module.Module moduleName path exports ammendedImports decls
  where
    ammendedImports =
      importDictToList $
        foldr addImport (if noPrelude then Map.empty else defaultImports) imports


importDictToList :: ImportDict -> [(Module.Name, Module.ImportMethod)]
importDictToList dict =
    concatMap toImports (Map.toList dict)
  where
    toImports (name, (qualifiers, listing@(Var.Listing explicits open))) =
        map (\qualifier -> (name, Module.As qualifier)) qualifiers
        ++
        if open || not (null explicits)
          then [(name, Module.Open listing)]
          else []


addImport :: (Module.Name, Module.ImportMethod) -> ImportDict -> ImportDict
addImport (name, method) importDict =
    Map.alter mergeMethods name importDict
  where
    mergeMethods :: Maybe ([String], Var.Listing Var.Value)
                 -> Maybe ([String], Var.Listing Var.Value)
    mergeMethods entry =
      let (qualifiers, listing) =
              case entry of
                Nothing -> ([], Var.Listing [] False)
                Just v -> v
      in
          case method of
            Module.As qualifier ->
                Just (qualifier : qualifiers, listing)

            Module.Open newListing ->
                Just (qualifiers, mergeListings newListing listing)

    mergeListings (Var.Listing explicits1 open1) (Var.Listing explicits2 open2) =
        Var.Listing
          (Set.toList (Set.fromList (explicits1 ++ explicits2)))
          (open1 || open2)
