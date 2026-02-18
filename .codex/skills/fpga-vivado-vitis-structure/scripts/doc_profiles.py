#!/usr/bin/env python3
"""Shared metadata for Vivado doc helpers.

This module centralizes script-level defaults and CLI document selection for:
- UG934 (AXI4-Stream Video IP and System Design Guide)
- UG835 (Vivado Tcl Command Reference Guide)
 - UG892 (Vivado Design Flows Overview)
 - UG896 (Designing with IP)
 - UG1118 (Creating and Packaging Custom IP)
- UG896 (Designing with IP)
"""

from __future__ import annotations

import re
from dataclasses import dataclass


@dataclass(frozen=True)
class ExtractProfile:
    pdf_path: str
    out_dir: str
    markdown_name: str
    page_map_name: str
    title: str
    default_method: str = "markitdown"


@dataclass(frozen=True)
class SplitProfile:
    input_markdown: str
    out_dir: str
    index_json: str
    index_yaml: str
    sections_dir: str
    toc_heading: str
    toc_entry_pattern: str
    chapter_pattern: str
    appendix_pattern: str | None


@dataclass(frozen=True)
class BuildRule:
    id: str
    rule: str
    patterns: tuple[str, ...]
    keywords: tuple[str, ...]
    snippet_limit: int = 4


@dataclass(frozen=True)
class BuildProfile:
    input_markdown: str
    index_path: str
    out_markdown: str
    out_json: str
    heading: str
    intro: tuple[str, ...]
    usage: tuple[str, ...]
    rules: tuple[BuildRule, ...]


@dataclass(frozen=True)
class DocProfile:
    doc_id: str
    extract: ExtractProfile
    split: SplitProfile
    build: BuildProfile | None
    query_dir: str


def _ref_root(doc_id: str) -> str:
    return f".codex/skills/fpga-vivado-vitis-structure/references/{doc_id}"


DOCS: dict[str, DocProfile] = {
    "ug934": DocProfile(
        doc_id="ug934",
        extract=ExtractProfile(
            pdf_path="amd-docs/ug934_axi_videoIP.pdf",
            out_dir=_ref_root("ug934"),
            markdown_name="ug934.full.md",
            page_map_name="page_map.json",
            title="UG934 AXI4-Stream Video IP and System Design Guide",
        ),
        split=SplitProfile(
            input_markdown=f"{_ref_root('ug934')}/ug934.full.md",
            out_dir=_ref_root("ug934"),
            index_json=f"{_ref_root('ug934')}/index.json",
            index_yaml=f"{_ref_root('ug934')}/index.yaml",
            sections_dir="sections",
            toc_heading="Table of Contents",
            toc_entry_pattern=r"^(?P<title>.+?)\s+(?:\.\s*){3,}(?P<page>\d+)\s*$",
            chapter_pattern=r"^Chapter\s+(?P<num>\d+)(?::\s*(?P<title>.+))?$",
            appendix_pattern=r"^Appendix\s+(?P<letter>[A-Z])(?::\s*(?P<title>.+))?$",
        ),
        build=BuildProfile(
            input_markdown=f"{_ref_root('ug934')}/ug934.full.md",
            index_path=f"{_ref_root('ug934')}/index.json",
            out_markdown=f"{_ref_root('ug934')}/axi_video_musts.md",
            out_json=f"{_ref_root('ug934')}/axi_video_musts.json",
            heading="# UG934 AXI4-Stream Video Rules",
            intro=(
                "Derived from `ug934.full.md` generated with MarkItDown + pdftotext page maps.",
                "",
                "## Non-negotiable Protocol Rules",
            ),
            usage=(
                "- Apply these rules when modifying AXI4-Stream video paths, framing, or protocol adaptation logic.",
                "- If ambiguity remains, inspect the related split section files under `references/ug934/sections/`.",
            ),
            rules=(
                BuildRule(
                    id="sof-tuser0",
                    rule="Map Start Of Frame (SOF) to AXI4-Stream `TUSER[0]` and assert it only on the first valid pixel of each frame/field.",
                    patterns=(r"\bSOF\b", r"TUSER0|tuser\[0\]"),
                    keywords=("start of frame", "sof", "tuser"),
                ),
                BuildRule(
                    id="eol-tlast",
                    rule="Map End Of Line (EOL) to AXI4-Stream `TLAST` and assert it on the last valid pixel of each line.",
                    patterns=(r"\bEOL\b", r"\bTLAST\b", r"End Of Line"),
                    keywords=("end of line", "eol", "tlast"),
                ),
                BuildRule(
                    id="active-video-only",
                    rule="Transfer only active video samples on AXI4-Stream video; blanking intervals are not transported.",
                    patterns=(r"active video", r"Blank periods", r"not transferred"),
                    keywords=("active video", "blank", "timing"),
                ),
                BuildRule(
                    id="ancillary-not-in-video-stream",
                    rule="Do not treat ancillary/non-video payload as regular AXI4-Stream video pixels; deembed/discard or handle separately.",
                    patterns=(r"ancillary data", r"deembedded|deembed", r"non-video"),
                    keywords=("ancillary", "deembed", "non-video"),
                ),
            ),
        ),
        query_dir=_ref_root("ug934"),
    ),
    "ug835": DocProfile(
        doc_id="ug835",
        extract=ExtractProfile(
            pdf_path="amd-docs/ug835-vivado-tcl-commands-en-us-2025.2.pdf",
            out_dir=_ref_root("ug835"),
            markdown_name="ug835.full.md",
            page_map_name="page_map.json",
            title="UG835 Vivado Tcl Command Reference Guide",
        ),
        split=SplitProfile(
            input_markdown=f"{_ref_root('ug835')}/ug835.full.md",
            out_dir=_ref_root("ug835"),
            index_json=f"{_ref_root('ug835')}/index.json",
            index_yaml=f"{_ref_root('ug835')}/index.yaml",
            sections_dir="sections",
            toc_heading="Table of Contents",
            toc_entry_pattern=r"^(?P<title>.+?)(?:\s*\.+\s*)(?P<page>\d+)\s*$",
            chapter_pattern=r"^Chapter\s+(?P<num>\d+):\s*(?P<title>.+)$",
            appendix_pattern=r"^Appendix\s+(?P<letter>[A-Z]):\s*(?P<title>.+)$",
        ),
        build=None,
        query_dir=_ref_root("ug835"),
    ),
    "ug896": DocProfile(
        doc_id="ug896",
        extract=ExtractProfile(
            pdf_path="amd-docs/ug896-vivado-ip-en-us-2025.2.pdf",
            out_dir=_ref_root("ug896"),
            markdown_name="ug896.full.md",
            page_map_name="page_map.json",
            title="UG896 Vivado Design Suite User Guide: Designing with IP",
        ),
        split=SplitProfile(
            input_markdown=f"{_ref_root('ug896')}/ug896.full.md",
            out_dir=_ref_root("ug896"),
            index_json=f"{_ref_root('ug896')}/index.json",
            index_yaml=f"{_ref_root('ug896')}/index.yaml",
            sections_dir="sections",
            toc_heading="Table of Contents",
            toc_entry_pattern=r"^(?P<title>.+?)(?:\s*\.+\s*)(?P<page>\d+)\s*$",
            chapter_pattern=r"^Chapter\s+(?P<num>\d+):\s*(?P<title>.+)$",
            appendix_pattern=r"^Appendix\s+(?P<letter>[A-Z]):\s*(?P<title>.+)$",
        ),
        build=None,
        query_dir=_ref_root("ug896"),
    ),
    "ug1118": DocProfile(
        doc_id="ug1118",
        extract=ExtractProfile(
            pdf_path="amd-docs/ug1118-vivado-creating-packaging-custom-ip-en-us-2025.2.pdf",
            out_dir=_ref_root("ug1118"),
            markdown_name="ug1118.full.md",
            page_map_name="page_map.json",
            title="UG1118 Creating and Packaging Custom IP",
        ),
        split=SplitProfile(
            input_markdown=f"{_ref_root('ug1118')}/ug1118.full.md",
            out_dir=_ref_root("ug1118"),
            index_json=f"{_ref_root('ug1118')}/index.json",
            index_yaml=f"{_ref_root('ug1118')}/index.yaml",
            sections_dir="sections",
            toc_heading="Table of Contents",
            toc_entry_pattern=r"^(?P<title>.+?)(?:\s*\.+\s*)(?P<page>\d+)\s*$",
            chapter_pattern=r"^Chapter\s+(?P<num>\d+):\s*(?P<title>.+)$",
            appendix_pattern=r"^Appendix\s+(?P<letter>[A-Z]):\s*(?P<title>.+)$",
        ),
        build=None,
        query_dir=_ref_root("ug1118"),
    ),
    "ug892": DocProfile(
        doc_id="ug892",
        extract=ExtractProfile(
            pdf_path="amd-docs/ug892-vivado-design-flows-overview-en-us-2025.1.pdf",
            out_dir=_ref_root("ug892"),
            markdown_name="ug892.full.md",
            page_map_name="page_map.json",
            title="UG892 Vivado Design Flows Overview",
        ),
        split=SplitProfile(
            input_markdown=f"{_ref_root('ug892')}/ug892.full.md",
            out_dir=_ref_root("ug892"),
            index_json=f"{_ref_root('ug892')}/index.json",
            index_yaml=f"{_ref_root('ug892')}/index.yaml",
            sections_dir="sections",
            toc_heading="Table of Contents",
            toc_entry_pattern=r"^(?P<title>.+?)(?:\s*\.+\s*)(?P<page>\d+)\s*$",
            chapter_pattern=r"^Chapter\s+(?P<num>\d+):\s*(?P<title>.+)$",
            appendix_pattern=r"^Appendix\s+(?P<letter>[A-Z]):\s*(?P<title>.+)$",
        ),
        build=BuildProfile(
            input_markdown=f"{_ref_root('ug892')}/ug892.full.md",
            index_path=f"{_ref_root('ug892')}/index.json",
            out_markdown=f"{_ref_root('ug892')}/revision_control_musts.md",
            out_json=f"{_ref_root('ug892')}/revision_control_musts.json",
            heading="# UG892 Revision-Control Rules",
            intro=(
                "Derived from `ug892.full.md` generated with MarkItDown + pdftotext page maps.",
                "",
                "## Non-negotiable Workflow Rules",
            ),
            usage=(
                "- Apply these rules when defining Git policy and Vivado project regeneration scripts.",
                "- Keep UG892 section files under `references/ug892/sections/` for detailed context.",
            ),
            rules=(
                BuildRule(
                    id="external-sources-preferred",
                    rule="Keep RTL/XDC/DCP sources external to the Vivado project and add them with add_* commands instead of import_*.",
                    patterns=(r"RTL, XDC, and DCP", r"kept external", r"add_\*", r"import_\*"),
                    keywords=("RTL, XDC, and DCP", "Project Source Types"),
                ),
                BuildRule(
                    id="ip-xci-plus-repo",
                    rule="Preserve IP repositories together with XCI files; generated outputs are optional unless intentionally locking IP/version state.",
                    patterns=(r"XCI", r"Preserving the IP repository", r"Checking in the XCI file", r"Locked IP"),
                    keywords=("XCI", "Project Source Types"),
                ),
                BuildRule(
                    id="bd-file-or-write-bd-tcl",
                    rule="For block designs, preserve the BD definition and keep required IP repos available; write_bd_tcl is a supported recreation method.",
                    patterns=(r"To revision control a block design", r"write_bd_tcl", r"\bBD\b"),
                    keywords=("BD", "Project Source Types"),
                ),
                BuildRule(
                    id="script-based-preferred-for-clean-git",
                    rule="Use a script-based project recreation flow for minimal Git state, and keep recreation scripts versioned and tested regularly.",
                    patterns=(r"script-based", r"Generate a script to recreate", r"write_project_tcl", r"Test your methodology"),
                    keywords=("Methods to Revision Control a Project", "Script-based"),
                ),
                BuildRule(
                    id="optional-output-files",
                    rule="Optionally revision-control handoff and debug outputs (XSA, bitstream/PDI, LTX, intermediate DCPs, IP outputs) when needed for delivery workflows.",
                    patterns=(
                        r"Output Files to Optionally Revision Control",
                        r"XSA files",
                        r"Bitsteams/PDIs",
                        r"LTX",
                        r"Intermediate DCP",
                    ),
                    keywords=("Output Files to Optionally Revision Control",),
                ),
                BuildRule(
                    id="archive-project-for-portable-snapshot",
                    rule="Use archive_project to produce portable full-project zip snapshots, including optional run results and remote sources.",
                    patterns=(r"archive_project", r"compress your entire project into a zip", r"run results", r"remote source"),
                    keywords=("Archiving Designs", "archive_project"),
                ),
            ),
        ),
        query_dir=_ref_root("ug892"),
    ),
}


def normalize_doc_id(value: str | None) -> str | None:
    if value is None:
        return None
    text = value.strip().lower()
    m = re.search(r"\b(?:ug)?(?P<num>1118|934|835|892|896|34|35|92|96)\b", text)
    if not m:
        return None
    num = m.group("num")
    if num == "1118":
        return "ug1118"
    if num in ("34", "934"):
        return "ug934"
    if num in ("35", "835"):
        return "ug835"
    if num in ("92", "892"):
        return "ug892"
    if num in ("96", "896"):
        return "ug896"
    return None


def get_profile(arg_doc: str | None) -> DocProfile:
    doc_id = normalize_doc_id(arg_doc)
    if doc_id not in DOCS:
        raise KeyError(f"Unable to infer documentation ID from script or --doc: {arg_doc!r}")
    return DOCS[doc_id]
