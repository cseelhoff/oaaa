"""Training loop, replay buffer, losses (plan.md §6.7–§6.12)."""

from .losses import alphazero_loss
from .replay import Replay, Sample
from .self_play import collect_game
from .trainer import Trainer, TrainerConfig

__all__ = [
    "Replay",
    "Sample",
    "Trainer",
    "TrainerConfig",
    "alphazero_loss",
    "collect_game",
]
