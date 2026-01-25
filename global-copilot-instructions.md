# Global Copilot Instructions

This file contains general instructions for GitHub Copilot to improve code generation and suggestions.

## General Guidelines

### Code Quality
- Write clean, maintainable, and well-documented code
- Follow the principle of least surprise
- Prefer readability over cleverness
- Use meaningful variable and function names
- Keep functions small and focused on a single responsibility

### Best Practices
- Follow the existing code style and conventions in the project
- Write self-documenting code with clear intent
- Add comments for complex logic or non-obvious decisions
- Handle errors gracefully with proper error messages
- Validate inputs and handle edge cases

### Documentation
- Provide clear and concise documentation for public APIs
- Include usage examples where appropriate
- Document assumptions and limitations
- Keep documentation up-to-date with code changes

### Testing
- Write tests for new functionality
- Ensure tests are readable and maintainable
- Test edge cases and error conditions
- Follow the existing testing patterns in the project

### Security
- Never hardcode sensitive information (passwords, API keys, tokens)
- Validate and sanitize user inputs
- Follow security best practices for the language/framework
- Use parameterized queries to prevent injection attacks

### Performance
- Consider performance implications of code changes
- Avoid premature optimization
- Profile before optimizing
- Use appropriate data structures and algorithms

## Language-Specific Guidelines

### Python
- Follow PEP 8 style guide
- Use type hints where appropriate
- Prefer list comprehensions and generators for readability
- Use context managers for resource management

### JavaScript/TypeScript
- Use modern ES6+ features
- Prefer const over let, avoid var
- Use async/await over promise chains
- Enable strict mode in TypeScript

### Java
- Follow Java naming conventions
- Use appropriate access modifiers
- Prefer composition over inheritance
- Use try-with-resources for resource management

### Go
- Follow effective Go guidelines
- Handle errors explicitly
- Use defer for cleanup
- Keep interfaces small

## Version Control

- Write clear, descriptive commit messages
- Keep commits atomic and focused
- Reference issue numbers in commit messages when applicable
- Review changes before committing

---

*Note: These instructions can be updated as needed to reflect project-specific requirements or team preferences.*
