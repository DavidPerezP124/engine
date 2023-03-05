#ifndef EASYWSCLIENT_HPP_20120819_MIOFVASDTNUASZDQPLFD
#define EASYWSCLIENT_HPP_20120819_MIOFVASDTNUASZDQPLFD

#include <string>
#include <vector>
#include <iostream>
#include <string>
#include <memory>
#include <mutex>
#include <deque>
#include <thread>
#include <chrono>
#include <atomic>
#include <assert.h>

namespace easywsclient {

struct Callback_Imp { virtual void operator()(const std::string& message) = 0; };
struct BytesCallback_Imp { virtual void operator()(const std::vector<uint8_t>& message) = 0; };

class WebSocket {
  public:
    typedef WebSocket * pointer;
    typedef enum readyStateValues { CLOSING, CLOSED, CONNECTING, OPEN } readyStateValues;

    // Factories:
    static pointer create_dummy();
    static pointer from_url(const std::string& url, const std::string& origin = std::string());
    static pointer from_url_no_mask(const std::string& url, const std::string& origin = std::string());

    // Interfaces:
    virtual ~WebSocket() { }
    virtual void poll(int timeout = 0) = 0; // timeout in milliseconds
    virtual void send(const std::string& message) = 0;
    virtual void sendBinary(const std::string& message) = 0;
    virtual void sendBinary(const std::vector<uint8_t>& message) = 0;
    virtual void sendPing() = 0;
    virtual void close() = 0;
    virtual readyStateValues getReadyState() const = 0;

    template<class Callable>
    void dispatch(Callable callable)
        // For callbacks that accept a string argument.
    { // N.B. this is compatible with both C++11 lambdas, functors and C function pointers
        struct _Callback : public Callback_Imp {
            Callable& callable;
            _Callback(Callable& callable) : callable(callable) { }
            void operator()(const std::string& message) { callable(message); }
        };
        _Callback callback(callable);
        _dispatch(callback);
    }

    template<class Callable>
    void dispatchBinary(Callable callable)
        // For callbacks that accept a std::vector<uint8_t> argument.
    { // N.B. this is compatible with both C++11 lambdas, functors and C function pointers
        struct _Callback : public BytesCallback_Imp {
            Callable& callable;
            _Callback(Callable& callable) : callable(callable) { }
            void operator()(const std::vector<uint8_t>& message) { callable(message); }
        };
        _Callback callback(callable);
        _dispatchBinary(callback);
    }

  protected:
    virtual void _dispatch(Callback_Imp& callable) = 0;
    virtual void _dispatchBinary(BytesCallback_Imp& callable) = 0;
};

} // namespace easywsclient


// a simple, thread-safe queue with (mostly) non-blocking reads and writes

// eastwsclient isn't thread safe, so this is a really simple
// thread-safe wrapper for it.

namespace non_blocking {
template <class T>
class Queue {
    mutable std::mutex m;
    std::deque<T> data;
public:
    void push(T const &input) { 
        std::lock_guard<std::mutex> L(m);
        data.push_back(input);
    }

    bool pop(T &output) {
        std::lock_guard<std::mutex> L(m);
        if (data.empty())
            return false;
        output = data.front();
        data.pop_front();
        return true;
    }
};
}
class Ws {
  
    std::thread runner;
    std::thread messageThread;

    non_blocking::Queue<std::string> outgoing;
    non_blocking::Queue<std::string> incoming;
    std::atomic<bool> running { true };
public:



    class WsDelegate {
      public:
        virtual void HandleMessage(const std::string& message) = 0;
    };
    WsDelegate *delegate;

    void send(std::string const &s) { outgoing.push(s); }
    bool recv(std::string &s) { return incoming.pop(s); }
    void listeningThread(std::thread &t) {  }

    Ws(std::string url) {
        using easywsclient::WebSocket;

        runner = std::thread([=] {
            std::unique_ptr<WebSocket> ws(WebSocket::from_url(url));
            while (running) {
                if (ws->getReadyState() == WebSocket::CLOSED)
                    break;
                std::string data;
                if (outgoing.pop(data))
                    ws->send(data);
                ws->poll(3);
                ws->dispatch([&](const std::string & message) {
                    
                    delegate->HandleMessage(message);
                    incoming.push(message);
                });
            }
            fprintf(stderr, ">>> %s \n", "Closing ws");
            ws->close();
            ws->poll();
        });
        fprintf(stderr, ">>> %d \n", runner.joinable());
    }
    void close() { 
      running = false; 
    }
    ~Ws() { if (runner.joinable()) runner.join(); }
};

#endif /* EASYWSCLIENT_HPP_20120819_MIOFVASDTNUASZDQPLFD */

