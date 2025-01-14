{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE DeriveFoldable      #-}
{-# LANGUAGE DeriveFunctor       #-}
{-# LANGUAGE DeriveTraversable   #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
module GenUtils where

import Control.Lens (each, ix, (%~), (&))
import Data.Char    (toUpper)
import Data.Maybe   (fromMaybe)
import Data.Text    (Text)
import GHC.Generics     (Generic)

import qualified Zinza                as Z
import qualified Data.Algorithm.Diff as Diff
import qualified Data.Map            as Map
import qualified Data.Set            as Set
import qualified Data.Text           as T

-------------------------------------------------------------------------------
-- License List version
-------------------------------------------------------------------------------

-- | SPDX license list version
data SPDXLicenseListVersion
    = SPDXLicenseListVersion_3_0
    | SPDXLicenseListVersion_3_2
    | SPDXLicenseListVersion_3_6
  deriving (Eq, Ord, Show, Enum, Bounded)

allVers :: Set.Set SPDXLicenseListVersion
allVers =  Set.fromList [minBound .. maxBound]

prettyVer :: SPDXLicenseListVersion -> Text
prettyVer SPDXLicenseListVersion_3_6 = "SPDX License List 3.6"
prettyVer SPDXLicenseListVersion_3_2 = "SPDX License List 3.2"
prettyVer SPDXLicenseListVersion_3_0 = "SPDX License List 3.0"

-------------------------------------------------------------------------------
-- Per version
-------------------------------------------------------------------------------

data PerV a = PerV a a a
  deriving (Functor, Foldable, Traversable)

-------------------------------------------------------------------------------
-- Sorting
-------------------------------------------------------------------------------

newtype OrdT = OrdT Text deriving (Eq)

instance Ord OrdT where
    compare (OrdT a) (OrdT b)
        | a == b             = EQ
        | a `T.isPrefixOf` b = GT
        | b `T.isPrefixOf` a = LT
        | otherwise          = compare a b

-------------------------------------------------------------------------------
-- Commmons
-------------------------------------------------------------------------------

header :: String
header = "-- This file is generated. See Makefile's spdx rule"

-------------------------------------------------------------------------------
-- Tools
-------------------------------------------------------------------------------

combine
    :: forall a b tag. (Ord b, Ord tag, Enum tag, Bounded tag)
    => (a -> b)
    -> (tag -> [a])
    -> [(a, Set.Set tag)]
combine f t
    = map addTags
    $ foldr process [] [ minBound .. maxBound ]
  where
    unDiff :: Diff.Diff a -> a
    unDiff (Diff.First a)  = a
    unDiff (Diff.Second a) = a
    unDiff (Diff.Both _ a) = a -- important we prefer latter versions!

    addTags :: a -> (a, Set.Set tag)
    addTags a = (a, fromMaybe Set.empty (Map.lookup (f a) tags))

    process :: tag -> [a] -> [a]
    process tag as = map unDiff $ Diff.getDiffBy (\x y -> f x == f y) (t tag) as

    tags :: Map.Map b (Set.Set tag)
    tags = Map.fromListWith Set.union
        [ (f a, Set.singleton tag)
        | tag <- [ minBound .. maxBound ]
        , a <- t tag
        ]

ordNubOn :: Ord b => (a -> b) -> [a] -> [a]
ordNubOn f = go Set.empty where
    go _    [] = []
    go past (a:as)
        | b `Set.member` past = go past as
        | otherwise           = a :  go (Set.insert b past) as
      where
        b = f a

textShow :: Text -> Text
textShow = T.pack . show

toConstructorName :: Text -> Text
toConstructorName t = t
    & each %~ f
    & ix 0 %~ toUpper
    & special
  where
    f '.' = '_'
    f '-' = '_'
    f '+' = '\''
    f c   = c

    special :: Text -> Text
    special "0BSD"          = "NullBSD"
    special "389_exception" = "DS389_exception"
    special u               = u

mkList :: [Text] -> Text
mkList []     = "    []"
mkList (x:xs) =
    "    [ " <> x <> "\n"
    <> foldMap (\x' -> "    , " <> x' <> "\n") xs
    <> "    ]"

-------------------------------------------------------------------------------
-- Zinza inputs
-------------------------------------------------------------------------------

data Input = Input
    { inputLicenseIds      :: Text
    , inputLicenses        :: [InputLicense]
    , inputLicenseList_all :: Text
    , inputLicenseList_3_0 :: Text
    , inputLicenseList_3_2 :: Text
    , inputLicenseList_3_6 :: Text
    }
  deriving (Show, Generic)

instance Z.Zinza Input where
    toType  = Z.genericToTypeSFP
    toValue = Z.genericToValueSFP

data InputLicense = InputLicense
    { ilConstructor   :: Text
    , ilId            :: Text
    , ilName          :: Text
    , ilIsOsiApproved :: Bool
    }
  deriving (Show, Generic)

instance Z.Zinza InputLicense where
    toType  = Z.genericToTypeSFP
    toValue = Z.genericToValueSFP
