NASM = nasm
LD = ld
NASMFLAGS = -f elf64 -O3
LDFLAGS = -s

SRCDIR = src
INCDIR = include
BUILDDIR = build

SOURCES = $(SRCDIR)/main.asm $(SRCDIR)/x11.asm $(SRCDIR)/render.asm \
          $(SRCDIR)/input.asm $(SRCDIR)/game.asm $(SRCDIR)/map.asm \
          $(SRCDIR)/entities.asm $(SRCDIR)/collision.asm $(SRCDIR)/hud.asm \
          $(SRCDIR)/math.asm $(SRCDIR)/data.asm

OBJECTS = $(patsubst $(SRCDIR)/%.asm,$(BUILDDIR)/%.o,$(SOURCES))

TARGET = lol

all: $(BUILDDIR) $(TARGET)

$(BUILDDIR):
	mkdir -p $(BUILDDIR)

$(TARGET): $(OBJECTS)
	$(LD) $(LDFLAGS) -o $@ $^

$(BUILDDIR)/%.o: $(SRCDIR)/%.asm $(wildcard $(INCDIR)/*.inc)
	$(NASM) $(NASMFLAGS) -I$(INCDIR)/ -o $@ $<

clean:
	rm -rf $(BUILDDIR) $(TARGET)

.PHONY: all clean
