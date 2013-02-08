module Language.Fixpoint.Interface (
    
    -- * Containing Constraints
    FInfo (..)
 
    -- * Function to invoke solver
  , solve

    -- * Function to determine outcome
  , resultExit
  
) where

{- Interfacing with Fixpoint Binary -}

import Data.Functor
import Data.List
import qualified Data.HashMap.Strict as M
import System.IO        (hPutStr, withFile, IOMode (..))
import System.Exit
import Text.Printf

import Language.Fixpoint.Types         hiding (kuts, lits)
import Language.Fixpoint.Misc
import Language.Fixpoint.Parse            (rr)
import Language.Fixpoint.Files
import Text.PrettyPrint.HughesPJ

solve fn hqs fi
  =   {-# SCC "Solve" #-}  execFq fn hqs fi
  >>= {-# SCC "exitFq" #-} exitFq fn (cm fi) 
        
execFq fn hqs fi
  = do copyFiles hqs fq
       appendFile fq qstr 
       withFile fq AppendMode (\h -> {-# SCC "HPrintDump" #-} hPutStr h (render d))
       fp <- getFixpointPath
       ec <- {-# SCC "sysCall:Fixpoint" #-} executeShellCommand "fixpoint" $ execCmd fp fn 
       return ec
    where 
       fq   = extFileName Fq  fn
       d    = {-# SCC "FixPointify" #-} toFixpoint fi 
       qstr = render ((vcat $ toFix <$> (quals fi)) $$ text "\n")

-- execCmd fn = printf "fixpoint.native -notruekvars -refinesort -strictsortcheck -out %s %s" fo fq 
execCmd fp fn = printf "%s -notruekvars -refinesort -noslice -nosimple -strictsortcheck -sortedquals -out %s %s" fp fo fq 
  where fq    = extFileName Fq  fn
        fo    = extFileName Out fn

exitFq _ _ (ExitFailure n) | (n /= 1) 
  = return (Crash [] "Unknown Error", M.empty)
exitFq fn cm _ 
  = do str <- {-# SCC "readOut" #-} readFile (extFileName Out fn)
       let (x, y) = {-# SCC "parseFixOut" #-} rr ({-# SCC "sanitizeFixpointOutput" #-} sanitizeFixpointOutput str)
       return  $ (plugC cm x, y) 

plugC = fmap . mlookup

sanitizeFixpointOutput 
  = unlines 
  . filter (not . ("//"     `isPrefixOf`)) 
  . chopAfter ("//QUALIFIERS" `isPrefixOf`)
  . lines

resultExit Safe        = ExitSuccess
resultExit (Unsafe _)  = ExitFailure 1
resultExit _           = ExitFailure 2
