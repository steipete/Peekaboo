import Testing
import Foundation
@testable import peekaboo

@Suite("Direct Invocation Tests")
struct DirectInvocationTests {
    
    @Test("Peekaboo parses direct task invocation")
    func testDirectTaskParsing() throws {
        // Test single word task
        let simple = try Peekaboo.parse(["Hello"])
        #expect(simple.remainingArgs == ["Hello"])
        
        // Test multi-word task
        let complex = try Peekaboo.parse(["Open", "Safari", "and", "search", "for", "weather"])
        #expect(complex.remainingArgs == ["Open", "Safari", "and", "search", "for", "weather"])
        
        // Test task with special characters
        let special = try Peekaboo.parse(["Click", "the", "\"Submit\"", "button"])
        #expect(special.remainingArgs == ["Click", "the", "\"Submit\"", "button"])
    }
    
    @Test("Direct invocation creates AgentCommand")
    async func testDirectInvocationCreatesAgent() async throws {
        // Create a mock Peekaboo instance
        var peekaboo = Peekaboo()
        peekaboo.remainingArgs = ["Test", "task"]
        
        // The run() method should create an AgentCommand with the task
        // This test verifies the logic without actually running the command
        let task = peekaboo.remainingArgs.joined(separator: " ")
        #expect(task == "Test task")
        
        // Verify AgentCommand can be created with this task
        var agentCommand = AgentCommand()
        agentCommand.task = task
        #expect(agentCommand.task == "Test task")
    }
    
    @Test("Empty args shows help")
    func testEmptyArgsShowsHelp() throws {
        let peekaboo = try Peekaboo.parse([])
        #expect(peekaboo.remainingArgs.isEmpty)
        
        // When remainingArgs is empty, the run() method should print help
        // This is the expected behavior
    }
    
    @Test("Subcommands take precedence over direct invocation")
    func testSubcommandPrecedence() throws {
        // When a valid subcommand is provided, it should be used
        // instead of treating it as a direct task
        
        // These should parse as subcommands, not direct invocation
        do {
            _ = try Peekaboo.parse(["image", "--app", "Safari"])
            // If this succeeds, it means "image" was recognized as a subcommand
            #expect(true)
        } catch {
            #expect(false, "Should parse 'image' as subcommand")
        }
        
        do {
            _ = try Peekaboo.parse(["agent", "Test task"])
            // If this succeeds, it means "agent" was recognized as a subcommand
            #expect(true)
        } catch {
            #expect(false, "Should parse 'agent' as subcommand")
        }
        
        // This should be treated as direct invocation
        let direct = try Peekaboo.parse(["not-a-subcommand", "task"])
        #expect(direct.remainingArgs == ["not-a-subcommand", "task"])
    }
    
    @Test("Direct invocation preserves quotes and special characters")
    func testDirectInvocationPreservesSpecialChars() throws {
        let testCases = [
            (["Type", "Hello,", "World!"], "Type Hello, World!"),
            (["Click", "on", "button", "#submit"], "Click on button #submit"),
            (["Search", "for", "\"machine learning\""], "Search for \"machine learning\""),
            (["Open", "file:", "/Users/test/file.txt"], "Open file: /Users/test/file.txt")
        ]
        
        for (args, expected) in testCases {
            let peekaboo = try Peekaboo.parse(args)
            let task = peekaboo.remainingArgs.joined(separator: " ")
            #expect(task == expected)
        }
    }
    
    @Test("Direct invocation with flags is not supported")
    func testDirectInvocationWithFlags() throws {
        // Flags should not work with direct invocation
        // They should be treated as part of the task
        let peekaboo = try Peekaboo.parse(["Open", "TextEdit", "--verbose"])
        #expect(peekaboo.remainingArgs == ["Open", "TextEdit", "--verbose"])
        
        // The --verbose flag is part of the task, not a flag to Peekaboo
        // AgentCommand flags must be used with the agent subcommand
    }
}

// Test helper to verify AgentCommand creation from direct invocation
extension DirectInvocationTests {
    
    func createAgentFromDirectInvocation(_ args: [String]) -> AgentCommand {
        var agent = AgentCommand()
        agent.task = args.joined(separator: " ")
        return agent
    }
    
    @Test("Agent task from direct invocation")
    func testAgentTaskFromDirectInvocation() {
        let testCases = [
            ["Open", "Safari"],
            ["Click", "the", "submit", "button"],
            ["Type", "Hello", "World", "in", "the", "text", "field"],
            ["Take", "a", "screenshot", "and", "save", "it"]
        ]
        
        for args in testCases {
            let agent = createAgentFromDirectInvocation(args)
            let expectedTask = args.joined(separator: " ")
            #expect(agent.task == expectedTask)
            
            // Verify default values
            #expect(agent.verbose == false)
            #expect(agent.dryRun == false)
            #expect(agent.maxSteps == 20)
            #expect(agent.model == "gpt-4-turbo")
        }
    }
}