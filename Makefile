NASM = nasm
LD = ld
NASMFLAGS = -f elf64 -O3
LDFLAGS = -s

SRCDIR = src
INCDIR = include
BUILDDIR = build
TESTDIR = tests

SOURCES = $(SRCDIR)/main.asm $(SRCDIR)/x11.asm $(SRCDIR)/render.asm \
          $(SRCDIR)/input.asm $(SRCDIR)/game.asm $(SRCDIR)/map.asm \
          $(SRCDIR)/entities.asm $(SRCDIR)/collision.asm $(SRCDIR)/hud.asm \
          $(SRCDIR)/math.asm $(SRCDIR)/data.asm

OBJECTS = $(patsubst $(SRCDIR)/%.asm,$(BUILDDIR)/%.o,$(SOURCES))

# Objects without main.o (for linking tests)
LIB_OBJECTS = $(filter-out $(BUILDDIR)/main.o,$(OBJECTS))

TARGET = lol

# Test binaries
TESTS = $(BUILDDIR)/test_math $(BUILDDIR)/test_entities \
        $(BUILDDIR)/test_map $(BUILDDIR)/test_collision

all: $(BUILDDIR) $(TARGET)

$(BUILDDIR):
	mkdir -p $(BUILDDIR)

$(TARGET): $(OBJECTS)
	$(LD) $(LDFLAGS) -o $@ $^

$(BUILDDIR)/%.o: $(SRCDIR)/%.asm $(wildcard $(INCDIR)/*.inc)
	$(NASM) $(NASMFLAGS) -I$(INCDIR)/ -o $@ $<

# Test compilation
$(BUILDDIR)/test_%.o: $(TESTDIR)/test_%.asm $(wildcard $(INCDIR)/*.inc)
	$(NASM) $(NASMFLAGS) -I$(INCDIR)/ -o $@ $<

# Test stubs (provides dummy symbols for linking)
$(BUILDDIR)/test_stubs.o: $(TESTDIR)/test_stubs.asm $(wildcard $(INCDIR)/*.inc)
	$(NASM) $(NASMFLAGS) -I$(INCDIR)/ -o $@ $<

STUBS = $(BUILDDIR)/test_stubs.o

# Test linking - each test links with the lib objects it needs
$(BUILDDIR)/test_math: $(BUILDDIR)/test_math.o $(BUILDDIR)/math.o
	$(LD) -o $@ $^

$(BUILDDIR)/test_entities: $(BUILDDIR)/test_entities.o $(BUILDDIR)/entities.o
	$(LD) -o $@ $^

$(BUILDDIR)/test_map: $(BUILDDIR)/test_map.o $(BUILDDIR)/map.o $(BUILDDIR)/render.o \
                      $(STUBS)
	$(LD) -o $@ $^

$(BUILDDIR)/test_collision: $(BUILDDIR)/test_collision.o $(BUILDDIR)/collision.o \
                            $(BUILDDIR)/entities.o $(BUILDDIR)/data.o
	$(LD) -o $@ $^

# Build and run all tests
test: $(BUILDDIR) $(TESTS)
	@echo ""
	@echo "Running tests..."
	@echo "================================"
	@PASS=0; FAIL=0; \
	for t in $(TESTS); do \
		if $$t; then \
			PASS=$$((PASS + 1)); \
		else \
			FAIL=$$((FAIL + 1)); \
			echo "FAILED: $$t (exit code: $$?)"; \
		fi; \
	done; \
	echo "================================"; \
	echo "Results: $$PASS passed, $$FAIL failed"; \
	if [ $$FAIL -ne 0 ]; then exit 1; fi

clean:
	rm -rf $(BUILDDIR) $(TARGET)

.PHONY: all clean test
