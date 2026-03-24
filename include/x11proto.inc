; ============================================================================
; x11proto.inc - X11 protocol constants and structures
; ============================================================================

%ifndef X11PROTO_INC
%define X11PROTO_INC

; X11 socket path
%define X11_SOCKET_PATH "/tmp/.X11-unix/X0"
%define X11_SOCKET_PATH_LEN 20

; sockaddr_un structure
%define SOCKADDR_UN_SIZE 110

; X11 connection setup
%define X11_BYTE_ORDER_LSB  0x6C    ; little-endian
%define X11_PROTOCOL_MAJOR  11
%define X11_PROTOCOL_MINOR  0

; X11 opcodes
%define X11_CREATE_WINDOW   1
%define X11_MAP_WINDOW      8
%define X11_CREATE_GC       55
%define X11_PUT_IMAGE       72
%define X11_POLY_FILL_RECT  70
%define X11_INTERN_ATOM     16
%define X11_CHANGE_PROPERTY 18
%define X11_QUERY_EXTENSION 98
%define X11_GET_GEOMETRY    14

; X11 event masks
%define EVENT_KEY_PRESS         0x00000001
%define EVENT_KEY_RELEASE       0x00000002
%define EVENT_BUTTON_PRESS      0x00000004
%define EVENT_BUTTON_RELEASE    0x00000008
%define EVENT_POINTER_MOTION    0x00000040
%define EVENT_EXPOSURE          0x00008000
%define EVENT_STRUCTURE_NOTIFY  0x00020000

; X11 event types
%define EVENT_TYPE_KEY_PRESS    2
%define EVENT_TYPE_KEY_RELEASE  3
%define EVENT_TYPE_BUTTON_PRESS 4
%define EVENT_TYPE_BUTTON_RELEASE 5
%define EVENT_TYPE_MOTION       6
%define EVENT_TYPE_EXPOSE       12
%define EVENT_TYPE_MAP_NOTIFY   19
%define EVENT_TYPE_CONFIGURE    22
%define EVENT_TYPE_CLIENT_MSG   33

; X11 window classes
%define INPUT_OUTPUT    1
%define COPY_FROM_PARENT 0

; X11 GC value masks
%define GC_FOREGROUND   0x00000004
%define GC_BACKGROUND   0x00000008
%define GC_GRAPHICS_EXPOSURES 0x00010000

; X11 window attribute masks (CW)
%define CW_BACK_PIXEL       0x00000002
%define CW_EVENT_MASK       0x00000800
%define CW_COLORMAP         0x00002000

; X11 image format
%define ZIMAGE_FORMAT   2   ; ZPixmap

; MIT-SHM extension
%define MIT_SHM_NAME    "MIT-SHM"
%define MIT_SHM_NAME_LEN 7

; MIT-SHM sub-opcodes
%define SHM_ATTACH      1
%define SHM_DETACH      2
%define SHM_PUT_IMAGE   3

; Window dimensions
%define WINDOW_WIDTH    1280
%define WINDOW_HEIGHT   720
%define BYTES_PER_PIXEL 4
%define FRAMEBUFFER_SIZE (WINDOW_WIDTH * WINDOW_HEIGHT * BYTES_PER_PIXEL)

; Key codes (X11 keycodes)
%define KEY_ESCAPE  9
%define KEY_Q       24
%define KEY_W       25
%define KEY_E       26
%define KEY_R       27
%define KEY_D       40
%define KEY_F       41
%define KEY_A       38
%define KEY_S       39
%define KEY_SPACE   65
%define KEY_TAB     23
%define KEY_1       10
%define KEY_2       11
%define KEY_3       12
%define KEY_4       13

; Mouse buttons
%define MOUSE_LEFT      1
%define MOUSE_MIDDLE    2
%define MOUSE_RIGHT     3
%define MOUSE_SCROLL_UP 4
%define MOUSE_SCROLL_DN 5

%endif
