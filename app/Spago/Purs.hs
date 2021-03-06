module Spago.Purs where

import           Control.Monad          (when)
import           Control.Monad.IO.Class (liftIO)
import           Data.Maybe             (isNothing)
import qualified Data.Text              as Text
import           Data.Versions          as Version
import           Safe                   (headMay)
import qualified System.Process         as Process
import qualified Turtle                 as T hiding (die, echo)

import qualified Spago.Messages         as Messages
import           Spago.Turtle


newtype ModuleName = ModuleName { unModuleName :: T.Text }
newtype TargetPath = TargetPath { unTargetPath :: T.Text }
newtype SourcePath = SourcePath { unSourcePath :: T.Text }
newtype ExtraArg = ExtraArg { unExtraArg :: T.Text }

data WithMain = WithMain | WithoutMain


compile :: [SourcePath] -> [ExtraArg] -> IO ()
compile sourcePaths extraArgs = do
  let
    paths = Text.intercalate " " $ Messages.surroundQuote <$> map unSourcePath sourcePaths
    args  = Text.intercalate " " $ map unExtraArg extraArgs
    cmd = "purs compile " <> args <> " " <> paths
  runWithOutput cmd
    "Build succeeded."
    "Failed to build."

repl :: [SourcePath] -> [ExtraArg] -> IO ()
repl sourcePaths extraArgs = do
  let args  = Text.unpack
        <$> ["repl"]
        <> map unSourcePath sourcePaths
        <> map unExtraArg extraArgs
  T.view $ liftIO $ Process.callProcess "purs" args

bundle :: WithMain -> ModuleName -> TargetPath -> IO ()
bundle withMain (ModuleName moduleName) (TargetPath targetPath) = do
  let main = case withMain of
        WithMain    -> " --main " <> moduleName
        WithoutMain -> ""

      cmd
        = "purs bundle \"output/*/*.js\""
        <> " -m " <> moduleName
        <> main
        <> " -o " <> targetPath

  runWithOutput cmd
    ("Bundle succeeded and output file to " <> targetPath)
    ("Bundle failed.")


docs :: [SourcePath] -> IO ()
docs sourcePaths = do
  let
    paths = Text.intercalate " " $ Messages.surroundQuote <$> map unSourcePath sourcePaths
    cmd = "purs docs " <> paths <> " --format html"
  runWithOutput cmd
    ("Docs generated. Index is at " <> Messages.surroundQuote "./generated-docs/index.html")
    "Docs generation failed."

version :: IO (Maybe Version.SemVer)
version = do
  fullVersionText <- T.shellStrict "purs --version" T.empty >>= \case
    (T.ExitSuccess, out) -> pure out
    _ -> die "Failed to run 'purs --version'"
  versionText <- pure $ headMay $ Text.split (== ' ') fullVersionText
  parsed <- pure $ versionText >>= (hush . Version.semver)

  when (isNothing parsed) $ do
    echo $ Messages.failedToParseCommandOutput "purs --version" fullVersionText

  pure parsed


runWithOutput :: T.Text -> T.Text -> T.Text -> IO ()
runWithOutput command success failure = do
  T.shell command T.empty >>= \case
    T.ExitSuccess -> echo success
    T.ExitFailure _ -> die failure
