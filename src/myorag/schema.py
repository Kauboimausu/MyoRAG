from dataclasses import dataclass
from typing import Literal, get_args

RefType = Literal["bibr", "table", "figure", "formula", "foot"]


@dataclass 
class Author:
    names: str
    last: str 
    affiliation: str | None = None


@dataclass
class LocalReference:
    references_id: str | None
    type: RefType
    start: int
    end: int
    
    def __post_init__(self):
        if self.type not in get_args(RefType):
            raise ValueError(f"Unknown reference type: {self.type!r}")


@dataclass
class Paragraph:
    text: str
    references: list[LocalReference]


@dataclass
class Section:
    title: str | None
    section_number: str | None
    paragraphs: list[Paragraph]


@dataclass
class Table:
    id: str
    header: str | None
    footer: str | None
    notes: str | None
    rows: list[list[str]]


@dataclass
class Figure:
    id: str
    image: str | None  # ruta al archivo de imagen; GROBID no la da con processFulltextDocument
    header: str | None
    footer: str | None


@dataclass
class BibReference:
    id: str
    authors: list[Author]
    year: int | None
    title: str | None
    link: str | None


@dataclass
class Paper:
    id: str
    authors: list[Author]
    title: str
    abstract: list[Section]
    body: list[Section]
    figures: list[Figure]
    tables: list[Table]
    bibliography: list[BibReference]