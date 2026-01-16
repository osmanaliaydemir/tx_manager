using System;
using System.Net;

namespace TX_Manager.Application.Common.Exceptions;

public class XApiException : Exception
{
    public HttpStatusCode StatusCode { get; }
    public string? ResponseBody { get; }

    public XApiException(string message, HttpStatusCode statusCode, string? responseBody = null, Exception? inner = null)
        : base(message, inner)
    {
        StatusCode = statusCode;
        ResponseBody = responseBody;
    }
}

