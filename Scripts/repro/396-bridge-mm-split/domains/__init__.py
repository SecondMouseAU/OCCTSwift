"""Registers every domain's split config with split_bridge_mm.register_domain() on import.
Each module below is one domain's taxonomy, built the same way: run --report, inspect
UNCLASSIFIED, add overrides, repeat until 0 unresolved and 0 unclassified. Keep them one
module per domain, so each domain's config is reviewable on its own."""
from . import domain_io  # noqa: F401
from . import domain_topology  # noqa: F401
from . import domain_healing  # noqa: F401
from . import domain_geom2d  # noqa: F401
from . import domain_curve3d  # noqa: F401
from . import domain_surface  # noqa: F401
from . import domain_document  # noqa: F401
from . import domain_spatial  # noqa: F401
from . import domain_visualization  # noqa: F401
